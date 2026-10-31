function [indices,starts]=drawDateBlocks(nDays,L,stream)
%DRAWDATEBLOCKS Non-circular moving blocks, sampled with replacement.
% Every calendar date participates, including dates with no accepted records.
assert(L>=1&&L<=nDays&&L==floor(L),'poc:stats:BlockLength','Invalid block length.');
starts=randi(stream,nDays-L+1,ceil(nDays/L),1);
blocks=starts+(0:L-1);
indices=reshape(blocks.',[],1);indices=indices(1:nDays);
end
