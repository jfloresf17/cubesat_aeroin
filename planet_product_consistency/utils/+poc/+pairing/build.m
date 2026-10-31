function [decisions,pairs]=build(S,T,R,cfg,tolerance_ns,sample)
%BUILD Nearest valid native-epoch TLE, then latest ELIGIBLE state per UTC day.
% Selection never uses evaluated states or residual magnitudes.
rows=repmat(poc.schema("pair"),0,1);
inside=S.EpochUTC>=cfg.study.startUTC & S.EpochUTC<cfg.study.endUTC+caldays(1);
S=S(inside & ismember(S.HWID,R.HWID),:);
for i=1:height(S)
 p=poc.schema("pair");p.Sample=sample;p.HWID=S.HWID(i);
 p.StateID=S.RecordID(i);p.StateEpochTTns=S.EpochTTns(i);
 p.StateEpochUTC=S.EpochUTC(i);p.DateUTC=dateshift(S.EpochUTC(i),'start','day');
 p.StateArchiveDateUTC=S.ArchiveDateUTC(i);
 p.FreshnessConventionApproved=cfg.reporting.archiveDateConventionApproved;
 p.StateAgeLower_s=seconds(p.StateArchiveDateUTC-p.StateEpochUTC);
 p.StateAgeUpper_s=seconds(p.StateArchiveDateUTC+caldays(1)-p.StateEpochUTC);
 rr=find(R.HWID==S.HWID(i) & R.ValidFromUTC<=S.EpochUTC(i) & R.ValidToUTC>S.EpochUTC(i));
 if numel(rr)~=1
  p.Status="NO_UNIQUE_IDENTITY_INTERVAL";
 elseif S.Status(i)~="OK"
  p.Status="STATE_"+S.Status(i);
 else
  r=R(rr,:);p.Satellite=r.Satellite;p.CatalogID=r.CatalogID;
  p.IdentityVerified=r.HistoricallyVerified;
  if cfg.identity.requireHistoricalApproval && ~p.IdentityVerified
   p.Status="IDENTITY_NOT_HISTORICALLY_APPROVED";
  else
   same=T.CatalogID==r.CatalogID & T.EpochUTC>=r.ValidFromUTC & T.EpochUTC<r.ValidToUTC;
   valid=same & T.Status=="OK";
   if cfg.identity.requireHeaderHWID
    valid=valid & T.HeaderHWID==p.HWID;
   end
   candidates=find(valid);
   if isempty(candidates)
    p.Status="NO_VALID_TLE_FOR_IDENTITY";
   else
    delta=S.EpochTTns(i)-T.EpochTTns(candidates);
    in=abs(delta)<=tolerance_ns;
    candidates=candidates(in);delta=delta(in);
    if isempty(candidates)
     p.Status="NO_TLE_WITHIN_WINDOW";
    else
     score=table(abs(delta),T.EpochTTns(candidates),T.RecordID(candidates),candidates, ...
      'VariableNames',{'AbsDelta','Epoch','ID','CandidateRow'});
     score=sortrows(score,{'AbsDelta','Epoch','ID'});j=score.CandidateRow(1);
     p.TLEID=T.RecordID(j);p.TLEEpochTTns=T.EpochTTns(j);p.TLEEpochUTC=T.EpochUTC(j);
     p.DeltaTime_ns=p.StateEpochTTns-p.TLEEpochTTns;
     p.DeltaTime_s=double(p.DeltaTime_ns)/1e9;
     p.TLEArchiveDateUTC=T.ArchiveDateUTC(j);
     p.TLEAgeLower_s=seconds(p.TLEArchiveDateUTC-p.TLEEpochUTC);
     p.TLEAgeUpper_s=seconds(p.TLEArchiveDateUTC+caldays(1)-p.TLEEpochUTC);
     p.PairID=poc.io.hashText(p.StateID+"|"+p.TLEID);
     p.Status="ELIGIBLE";
    end
   end
  end
 end
 rows(end+1,1)=p; %#ok<AGROW>
end
decisions=poc.toTable(rows,"pair");
if isempty(decisions),pairs=decisions;return;end
eligible=find(decisions.Status=="ELIGIBLE");
if ~isempty(eligible)
 D=decisions(eligible,:);
 D=sortrows(D,{'HWID','DateUTC','StateEpochTTns','PairID'}, ...
  {'ascend','ascend','descend','ascend'});
 key=D.HWID+"|"+string(D.DateUTC,'yyyy-MM-dd');
 [~,first]=unique(key,'stable');keep=D.PairID(first);
 decisions.SelectedDaily=decisions.Status=="ELIGIBLE" & ismember(decisions.PairID,keep);
 decisions.Status(decisions.Status=="ELIGIBLE"&~decisions.SelectedDaily)="NOT_DAILY_SELECTED";
 decisions.Status(decisions.SelectedDaily)="ACCEPTED";
end
pairs=decisions(decisions.SelectedDaily,:);
if ~isempty(pairs)
 % A payload pair may occur only once; dedup does not manufacture independence.
 [~,u]=unique(pairs.PairID,'stable');pairs=pairs(u,:);
 [g,~]=findgroups(pairs.TLEID);n=accumarray(g,1);pairs.TLEReuseCount=n(g);
 pairs=sortrows(pairs,{'DateUTC','Satellite'});
 [tf,loc]=ismember(decisions.PairID,pairs.PairID);
 decisions.TLEReuseCount(tf)=pairs.TLEReuseCount(loc(tf));
end
end
