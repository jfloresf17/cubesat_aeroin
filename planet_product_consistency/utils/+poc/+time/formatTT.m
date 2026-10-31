function token=formatTT(ns)
%FORMATT Tightly defined decimal serialization for synthetic/test records.
negative=ns<0;ns=abs(int64(ns));
a=idivide(ns,int64(1000000000),'floor');b=rem(ns,int64(1000000000));
token=string(a)+"."+string(sprintf('%09d',b));
if negative,token="-"+token;end
end
