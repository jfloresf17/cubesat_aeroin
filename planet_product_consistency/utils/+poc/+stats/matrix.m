function X=matrix(R)
%MATRIX Numeric metric order used consistently by point and bootstrap routines.
X=R{:,{'Position_m','Velocity_mps','Radial_m','Transverse_m','Normal_m', ...
 'Ground_m','GroundEast_m','GroundNorth_m'}};
end
