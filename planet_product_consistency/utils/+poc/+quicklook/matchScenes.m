function [matches,sceneStatus]=matchScenes(scenes,states,tles,roster,opts)
%MATCHSCENES Enumerate every eligible scene-state-same-day TLE combination.
% SceneMinusState_s and SceneMinusTLE_s are signed (scene epoch minus record
% epoch). A TLE's NATIVE UTC epoch, not its archive date, must be on the same
% UTC calendar date as the scene. No 1 ms or 24 h TLE filter is applied.
assert(isscalar(opts.TimeToleranceSeconds)&&isfinite(opts.TimeToleranceSeconds) ...
 && opts.TimeToleranceSeconds>=0,'poc:quicklook:Tolerance', ...
 'TimeToleranceSeconds must be a finite nonnegative scalar.');
stateOK=states.Status=="OK" & ~isnat(states.EpochUTC);
tleOK=tles.Status=="OK" & ~isnat(tles.EpochUTC) & strlength(tles.HeaderHWID)>0;
stateMap=containers.Map('KeyType','char','ValueType','any');
stateIDs=unique(lower(states.HWID(stateOK)));
for k=1:numel(stateIDs)
 stateMap(char(stateIDs(k)))=find(stateOK & lower(states.HWID)==stateIDs(k));
end
tleMap=containers.Map('KeyType','char','ValueType','any');
tleIDs=find(tleOK);
if ~isempty(tleIDs)
 day=dateshift(tles.EpochUTC(tleIDs),'start','day');
 keys=lower(tles.HeaderHWID(tleIDs))+"|"+string(day,'yyyy-MM-dd');
 distinct=unique(keys);
 for k=1:numel(distinct)
  tleMap(char(distinct(k)))=tleIDs(keys==distinct(k));
 end
end
n=height(scenes);status=repmat("PENDING",n,1);
stateCount=zeros(n,1);tleCount=zeros(n,1);matchCount=zeros(n,1);
si=zeros(0,1);ci=zeros(0,1);ti=zeros(0,1);ri=zeros(0,1);
start=dateshift(opts.StartUTC,'start','day');
finish=dateshift(opts.EndUTC,'start','day')+caldays(1);
for k=1:n
 if scenes.MetadataStatus(k)~="OK" || isnat(scenes.AcquiredUTC(k))
  status(k)="INVALID_SCENE_METADATA";continue;
 end
 sceneTime=scenes.AcquiredUTC(k);
 if sceneTime<start || sceneTime>=finish
  status(k)="OUTSIDE_SEARCH_WINDOW";continue;
 end
 id=lower(strtrim(scenes.SatelliteID(k)));
 if isempty(regexp(char(id),'^[0-9a-f]{4}$','once'))
  status(k)="UNSUPPORTED_SATELLITE_ID";continue;
 end
 if ~isKey(stateMap,char(id))
  status(k)="NO_USABLE_STATE_FOR_SATELLITE";continue;
 end
 candidates=stateMap(char(id));
 offsets=seconds(sceneTime-states.EpochUTC(candidates));
 candidates=candidates(abs(offsets)<=opts.TimeToleranceSeconds);
 stateCount(k)=numel(candidates);
 if isempty(candidates)
  status(k)="NO_STATE_WITHIN_TOLERANCE";continue;
 end
 key=char(id+"|"+string(dateshift(sceneTime,'start','day'),'yyyy-MM-dd'));
 if ~isKey(tleMap,key)
  status(k)="NO_USABLE_SAME_DAY_TLE";continue;
 end
 possibleTLE=tleMap(key);tleCount(k)=numel(possibleTLE);
 % A valid roster interval adds evidence; a matching native TLE header is
 % still sufficient for an explicitly unverified exploratory candidate.
 rosterRows=find(roster.HWID==id & roster.ValidFromUTC<=sceneTime & ...
  roster.ValidToUTC>sceneTime);
 if numel(rosterRows)>1
  status(k)="AMBIGUOUS_ROSTER_INTERVAL";continue;
 end
 rosterRow=0;if ~isempty(rosterRows),rosterRow=rosterRows(1);end
 [stateGrid,tleGrid]=ndgrid(candidates(:),possibleTLE(:));
 count=numel(stateGrid);
 si=[si;repmat(k,count,1)]; %#ok<AGROW>
 ci=[ci;stateGrid(:)];ti=[ti;tleGrid(:)]; %#ok<AGROW>
 ri=[ri;repmat(rosterRow,count,1)]; %#ok<AGROW>
 matchCount(k)=count;status(k)="MATCHED";
 if rosterRow>0 && any(tles.CatalogID(possibleTLE)~=roster.CatalogID(rosterRow))
  status(k)="MATCHED_WITH_ROSTER_CONFLICT";
 end
end

% Retain all important scene metadata, plus native state/TLE provenance.
matches=scenes(si,:);
matches.StateRecordID=states.RecordID(ci);
matches.StateHWID=states.HWID(ci);
matches.StateEpochUTC=states.EpochUTC(ci);
matches.StateEpochTTns=states.EpochTTns(ci);
matches.StateArchiveDateUTC=states.ArchiveDateUTC(ci);
matches.StateSourcePath=states.SourcePath(ci);
matches.StateSourceSHA256=states.SourceSHA256(ci);
matches.StateRx_m=states.Rx_m(ci);matches.StateRy_m=states.Ry_m(ci);
matches.StateRz_m=states.Rz_m(ci);matches.StateVx_mps=states.Vx_mps(ci);
matches.StateVy_mps=states.Vy_mps(ci);matches.StateVz_mps=states.Vz_mps(ci);
matches.TLERecordID=tles.RecordID(ti);
matches.TLECatalogID=tles.CatalogID(ti);matches.TLEHeaderHWID=tles.HeaderHWID(ti);
matches.TLEEpochUTC=tles.EpochUTC(ti);
matches.TLEEpochTTns=tles.EpochTTns(ti);
matches.TLEArchiveDateUTC=tles.ArchiveDateUTC(ti);
matches.TLESourcePath=tles.SourcePath(ti);matches.TLESourceSHA256=tles.SourceSHA256(ti);
matches.TLEName=tles.Name(ti);matches.TLELine1=tles.Line1(ti);matches.TLELine2=tles.Line2(ti);
matches.SceneMinusState_s=seconds(scenes.AcquiredUTC(si)-states.EpochUTC(ci));
matches.AbsSceneMinusState_s=abs(matches.SceneMinusState_s);
matches.SceneMinusTLE_s=seconds(scenes.AcquiredUTC(si)-tles.EpochUTC(ti));
m=numel(si);matches.RosterSatellite=strings(m,1);
matches.IdentityVerified=false(m,1);matches.IdentityStatus=repmat("HEADER_ONLY_UNVERIFIED",m,1);
matches.MatchStatus=repmat("MATCHED",m,1);
for j=1:m
 r=ri(j);
 if r==0
  if any(roster.HWID==matches.StateHWID(j))
   matches.IdentityStatus(j)="ROSTER_OUTSIDE_INTERVAL";
  end
  continue;
 end
 matches.RosterSatellite(j)=roster.Satellite(r);
 if matches.TLECatalogID(j)~=roster.CatalogID(r)
  matches.IdentityStatus(j)="ROSTER_CATALOG_CONFLICT";
  matches.MatchStatus(j)="IDENTITY_CONFLICT";
 elseif matches.StateEpochUTC(j)<roster.ValidFromUTC(r) || ...
   matches.StateEpochUTC(j)>=roster.ValidToUTC(r) || ...
   matches.TLEEpochUTC(j)<roster.ValidFromUTC(r) || ...
   matches.TLEEpochUTC(j)>=roster.ValidToUTC(r)
  matches.IdentityStatus(j)="ROSTER_EPOCH_OUTSIDE_INTERVAL";
 elseif roster.HistoricallyVerified(r)
  matches.IdentityStatus(j)="HISTORICALLY_VERIFIED";
  matches.IdentityVerified(j)=true;
 else
  matches.IdentityStatus(j)="ROSTER_CANDIDATE_UNVERIFIED";
 end
end
if ~isempty(matches)
 matches=sortrows(matches,{'AcquiredUTC','SceneID','AbsSceneMinusState_s', ...
  'StateEpochUTC','TLEEpochUTC','StateRecordID','TLERecordID'});
end
sceneStatus=table(scenes.SceneID,scenes.SatelliteID,scenes.AcquiredUTC, ...
 scenes.MetadataStatus,status,stateCount,tleCount,matchCount, ...
 'VariableNames',{'SceneID','SatelliteID','AcquiredUTC','MetadataStatus', ...
 'Status','StateCandidateCount','SameDayTLECount','MatchCount'});
end
