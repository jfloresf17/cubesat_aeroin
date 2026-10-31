# Consistency of PlanetScope orbital products and published image footprints

**Manuscript methodology draft.** A preliminary MATLAB implementation covers matching, image-epoch propagation, footprint projection and per-match metrics. Several sensitivity experiments and independent validation steps remain research work.

## Abstract

This study proposes a time-matched comparison of PlanetScope orbital products and published image footprints. Scenes, Cartesian states and two-line elements (TLEs) are screened by identity, image quality and scene-to-state epoch separation. Both products are evaluated at the same nominal acquisition time and compared in radial–along-track–cross-track (RTN) and three-dimensional WGS84 coordinates. Shared pointing and swath assumptions are then used to project a candidate footprint from each orbit onto Earth. Each predicted polygon is compared with the same published scene polygon using coverage, overlap and boundary distances. Matching-tolerance and configurable pointing and swath scenarios can be assessed in separate runs; a common acquisition time-tag bias experiment remains unimplemented. Results represent conditional consistency because orbit and image products may share information and are not independently established truth.

## 1. Introduction and objective

Planet's public ephemerides platform provides Cartesian state-vector and TLE files ([Planet, public ephemerides](https://ephemerides.planet-labs.com/)). A historical Planet orbit-determination approach fitted a numerical orbit model to ranging observations ([Foster et al., 2015](https://arxiv.org/abs/1509.03270)); the available evidence does not establish that the current files were produced by that particular system. Image geometry also depends on sensor pointing and processing; apparent ground differences cannot automatically be attributed to orbital position ([Mueting and Bookhagen, 2024](https://doi.org/10.5194/esurf-12-1121-2024)).

The objective is to assess **orbital-product consistency at acquisition and conditional agreement between projected footprints and the published scene footprint**. The reference is the **whole published polygon at its nominal acquisition time**. The published geodetic centre is not used to aim, translate, fit or score either prediction. A modelled ray intercept is only an internal construction quantity.

**Workflow:** database → common-time states → pointing and swath projection → orbital and whole-footprint metrics → sensitivity analysis.

## 2. Database generation

### 2.1 Selection steps and decisions

| Step | Decision and retained fields |
|---|---|
| Source inventory | Read native Planet Cartesian/TLE archives and PSScene records. Preserve source path, satellite ID, native epoch and provenance; mark missing days. |
| Scene identity | Retain scene ID, satellite ID, strip ID, instrument, nominal UTC and GeoJSON footprint. Flag unresolved, duplicate or conflicting identities. |
| Cartesian time | Match each scene to its satellite’s native state. Use **±1 s inclusive** as the primary candidate window; retain signed time difference and all eligible records. |
| TLE time | Keep native TLE epochs on the **same UTC day** as the scene. This existing quick-look rule is not a ±1 s TLE filter; retain signed TLE age. |
| Quality | Begin with finalized, standard and ground-controlled scenes. Retain cloud, other categories and exclusion reasons for sensitivity analysis. |
| Image geometry | Retain catalogue view angle, satellite azimuth, sun azimuth/elevation and, where separately accessible, XML incidence and scan-line azimuth. XML retrieval is not automated. |
| Sampling | Retain scene–state–TLE combinations and group results by satellite, acquisition day and strip. Adjacent frames in a strip are not independent observations. |

For catalogue time $t_{\mathrm{image}}$ and native state epoch $t_C$,

$$
\Delta t_C=t_{\mathrm{image}}-t_C,\qquad |\Delta t_C|\leq1\ \mathrm{s}.
$$

For the native TLE epoch $t_T$, the same-day constraint and signed time offset are

$$
\operatorname{date}_{\mathrm{UTC}}(t_T)=\operatorname{date}_{\mathrm{UTC}}(t_{\mathrm{image}}),
\qquad \Delta t_T=t_{\mathrm{image}}-t_T.
$$

The TLE can be earlier or later than acquisition; a later TLE makes the comparison retrospective. Planet calls catalogue acquired a **nominal** UTC time; it is not demonstrated to be the precise time for every pixel or spectral band ([Planet, PSScene](https://docs.planet.com/data/imagery/planetscope/psscene/)). Printed decimal precision and a small recorded gap do not prove physical image-time accuracy.

### 2.2 Inventory and time sensitivity

Inspect the generated archive inventory and record actual coverage, identity
status, scene and strip counts, and exclusions for each run. To evaluate a range
of scene-to-state tolerances, run the quick-look search with a wider tolerance
and derive nested groups from that wider match table. A one-second-only search
cannot recover candidates outside that window. The primary threshold is an
experimental choice, not a universal tolerance.

## 3. Methodology: propagation and footprint projection

### 3.1 Propagators and common frame

Evaluate both orbit products at the same nominal image epoch $t_0=t_{\mathrm{image}}$. The implemented Cartesian baseline numerically integrates the two-body equations from its native state $(\mathbf r_C(t_C),\mathbf v_C(t_C))$ with MATLAB `ode113`:

$$
\dot{\mathbf r}_C=\mathbf v_C,\qquad
\dot{\mathbf v}_C=-\mu\frac{\mathbf r_C}{\lVert\mathbf r_C\rVert^3},
\qquad \mu=3.986004418\times10^{14}\ \mathrm{m^3\,s^{-2}}.
$$

This baseline does not include drag, oblateness or an orbit fit. J2 and a paper-inspired EGM96/NRLMSISE-00 scenario are future sensitivity work, not implemented alternatives in this runner. Evaluate each TLE with **SGP4**, not by treating its mean elements as an osculating Cartesian state ([Vallado et al., 2006](https://doi.org/10.2514/6.2006-6753)).

Foster et al. describe EGM96 degree/order 10, NRLMSISE-00 and a numerical orbit fit, but the public states do not provide the original observations or fit settings. The 2015 model informs a sensitivity scenario; it does not prove the exact 2026 processing ([Foster et al., 2015](https://arxiv.org/pdf/1509.03270#page=3)). Confirm Planet’s drag-coefficient convention before use; it is not TLE $B^*$.

Transform both states to a common Earth-fixed frame at $t_0$. Planet labels its Cartesian axes J2000; exact equivalence with ICRF needs review. Earth-fixed velocity includes the frame rotation rate:

$$
\mathbf r_E=R\mathbf r_I,\qquad
\mathbf v_E=R\mathbf v_I+\dot R\mathbf r_I.
$$

Here $R$ is evaluated at the target UTC, with $\dot R$ estimated by a centred difference over $\pm0.25$ s. Use reviewed leap seconds and Earth-orientation data. The pilot fetches or reuses USNO Earth-orientation data and assumes the Planet J2000 frame is ICRF. Independent verification of identities, this frame assumption and SGP4 remains necessary. Space-weather data would also be needed for a drag sensitivity model ([MathWorks, propagateOrbit](https://www.mathworks.com/help/aerotbx/ug/propagateorbit.html)).

### 3.2 Pointing and sensor-ray model

The **primary model is a nominal snapshot footprint at $t_0$**: a simplified rectangular sensor frame approximates the whole scene. This is not a claim that the composite image was captured in one instant.

XML incidence could provide a ground-view constraint in a future model, but the runner does not use it. Catalogue view angle is an **across-track** spacecraft angle, not automatically the same as incidence. XML azimuthAngle is the **scan-line direction**, not catalogue satellite azimuth. Sun angles describe illumination rather than pointing ([Planet, 2026](https://assets.planet.com/docs/Planet_Combined_Imagery_Product_Specs_letter_screen.pdf#page=79); [Planet, PSScene](https://docs.planet.com/data/imagery/planetscope/psscene/)).

Use the same numerical pointing rules, detector-axis mapping, angular bounds, ground model and timing scenario for both products. Each product constructs its local frame from its own position and Earth-fixed velocity, so identical local angles can still produce different Earth-fixed ray directions. Footprint differences therefore include orbit-dependent orientation as well as position effects. Unknown along-track angle, across-track sign and detector roll are assumptions. The runner tests both local across-track signs; it does not use catalogue satellite azimuth to resolve the sign. Future metadata-angle checks may constrain a solution, but **the published polygon and its centre must not force the pointing**. Handle ambiguous or near-nadir azimuths in any such extension.

| Model choice | Starting decision and alternatives |
|---|---|
| Evaluation time | Use nominal catalogue `acquired` for both products; a common time-tag bias scenario is future work. |
| Along-track pointing | Start with $\theta_A=0$ as a hypothesis; test other defensible values. |
| Across-track pointing | Treat $\theta_C=+\lvert\theta_{\mathrm{view}}\rvert$ and $\theta_C=-\lvert\theta_{\mathrm{view}}\rvert$, where $\theta_{\mathrm{view}}$ is the catalogue `view_angle`, as two shared sign scenarios until the convention is verified. In the model + is to the right of the Earth-fixed ground-track direction and − is to the left, looking forward. |
| Detector roll | Start with $\psi=0$ relative to the model axes; test the XML scan-line relationship and other roll scenarios. This is not a measured attitude. |
| Effective frame | Assign the nominal 19.6 km dimension to the model along-track axis and 32.5 km to cross-track at 475 km as an initial hypothesis; also test the swapped assignment. |
| Ground surface | Use the WGS84 ellipsoid, height zero; a datum-consistent DEM is an alternative scenario. |

All angles are converted to radians for the equations. Apply the same scenarios and solver to both orbital products; the catalogue data do not establish that the starting choices are the spacecraft's actual attitude or calibrated field of view.

Let $\mathbf n$ be the WGS84 local up direction beneath the satellite, $\mathbf z=-\mathbf n$ local down, $\mathbf x=\operatorname{unit}[\mathbf v_E-(\mathbf v_E\cdot\mathbf n)\mathbf n]$ the Earth-relative along-track direction, and $\mathbf y=\mathbf z\times\mathbf x$. This local frame is internal to the model; it is not matched to the published footprint centre. Under a stated convention, a boresight proxy for along- and across-track angles $\theta_A,\theta_C$ is

$$
\mathbf b=\operatorname{unit}\!\left(
\mathbf z+\tan\theta_A\,\mathbf x+\tan\theta_C\,\mathbf y\right).
$$

Project $\mathbf x$ onto the plane perpendicular to $\mathbf b$ to form $\mathbf e_{1,0}=\operatorname{unit}[\mathbf x-(\mathbf x\cdot\mathbf b)\mathbf b]$ and let $\mathbf e_{2,0}=\mathbf b\times\mathbf e_{1,0}$. For a stated detector-roll assumption $\psi$, the detector axes are

$$
\mathbf e_1=\cos\psi\,\mathbf e_{1,0}+\sin\psi\,\mathbf e_{2,0},\qquad
\mathbf e_2=-\sin\psi\,\mathbf e_{1,0}+\cos\psi\,\mathbf e_{2,0}.
$$

The relationship between $\psi$ and the XML scan-line bearing is an assumption requiring verification. Flag degenerate frame projections. For effective angular widths $F_1,F_2$, sample sensor-boundary rays using

$$
\mathbf d(u,v)=\operatorname{unit}\!\left[
\mathbf b+u\tan(F_1/2)\mathbf e_1+v\tan(F_2/2)\mathbf e_2
\right],\quad u,v\in[-1,1],\quad \max(\lvert u\rvert,\lvert v\rvert)=1.
$$

Equations use **radians**; convert Planet’s degree-valued fields before MATLAB trigonometric functions or consistently use degree-based equivalents. The axis, viewing-sign and angle conventions are hypotheses until verified. A calibrated sensor model additionally needs detector geometry, attitude, timing and terrain ([Aati and Avouac, 2020](https://doi.org/10.3390/rs12203418); [Sienkiewicz et al., 2024](https://doi.org/10.3389/frsen.2024.1474600), for general ray-intersection methodology).

As a proposed future metadata-constrained scenario, intersect a trial boresight with WGS84 and resolve the vector from that predicted ground intercept to the spacecraft into local east, north and up components $(E,N,U)$. This inversion is not implemented by the current runner. Under the hypotheses of an ellipsoid-normal incidence and ground-to-satellite azimuth, calculate

$$
i_{\mathrm{model}}=\operatorname{atan2}(\sqrt{E^2+N^2},U),\qquad
\alpha_{\mathrm{model}}=\operatorname{atan2}(E,N).
$$

Use XML incidence and catalogue azimuth to constrain trial pointing angles with the same solver, bounds and global direction convention for both products; handle circular azimuth differences, near-nadir ambiguity and no/multiple solutions explicitly. Compare `view_angle` separately unless the angle definitions are verified. The **published footprint and its geodetic centre are not optimization targets**. This inversion is conditional because the metadata may refer to different points or times and may share information with the delivered image.

### 3.3 Swath dimensions and temporal coverage

Planet reports nominal PSB.SD ground-scene dimensions of approximately **32.5 × 19.6 km at 475 km altitude**. These are not calibrated instantaneous detector FOVs; assignment to detector axes must be checked ([Planet, 2026, p. 17](https://assets.planet.com/docs/Planet_Combined_Imagery_Product_Specs_letter_screen.pdf#page=17)).

The implemented snapshot proxy uses a flat, nadir approximation to convert nominal dimension $L_j$ to an effective angular width:

$$
F_j^{\mathrm{proxy}}=2\arctan\!\left(\frac{L_j}{2H_{\mathrm{ref}}}\right),
\qquad H_{\mathrm{ref}}=475\ \mathrm{km}.
$$

The dimensions give approximately **3.9187°** and **2.3639°**. The 475 km reference height determines these angular widths only; ray tracing uses each propagated spacecraft position and altitude. These are proxy assumptions to vary, not measured FOVs. For comparison, an idealized flat across-track slice with altitude $H$, off-nadir angle $\theta$ and angular half-width $\delta$ has width

$$
W=H[\tan(\theta+\delta)-\tan(\theta-\delta)].
$$

**Alternative — time-swept swath:** with independently specified instantaneous detector extent and duration $D$, evaluate each orbit and pointing at the same $N$ sample times. For the assumed interval centred on $t_0$, the implementation calculates the discrete union

$$
t_k=t_0-\frac{D}{2}+\frac{k-1}{N-1}D,\qquad
Q_N=\bigcup_{k=1}^{N}F(t_k),\qquad N\geq2.
$$

This is a sampled union, not proof of continuous coverage; test temporal sampling convergence. Alternative time-tag reference or bias scenarios are not implemented. Do not add a whole nominal scene-length frame to a whole scene-length sweep: this can double-count coverage. Until timing is supported, the snapshot remains primary; an assumed sweep is a labelled sensitivity scenario ([Mueting and Bookhagen, 2024](https://doi.org/10.5194/esurf-12-1121-2024)).

### 3.4 WGS84 ray projection

For Earth-fixed spacecraft position $\mathbf S$ and unit boundary direction $\mathbf d$, intersect $\mathbf X(\tau)=\mathbf S+\tau\mathbf d$, $\tau>0$, with WGS84:

$$
\frac{X_x^2+X_y^2}{a^2}+\frac{X_z^2}{b^2}=1,\qquad
A\tau^2+B\tau+C=0,
$$

$$
\begin{aligned}
A&=(d_x^2+d_y^2)/a^2+d_z^2/b^2,\\
B&=2[(S_xd_x+S_yd_y)/a^2+S_zd_z/b^2],\\
C&=(S_x^2+S_y^2)/a^2+S_z^2/b^2-1.
\end{aligned}
$$

Select the **nearest positive real root**. Densify boundary rays and construct the predicted polygon. Flag missing, horizon or invalid intersections rather than recording zero overlap. A DEM scenario requires a compatible ellipsoidal height reference ([NASA NAIF, surface intercepts](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/sincpt_c.html)).

## 4. Metrics between orbital products

Evaluate all differences at the same epoch and in the same reviewed frame. Adopt the signed convention

$$
\Delta\mathbf r=\mathbf r_{\mathrm{TLE}}-\mathbf r_{\mathrm{Cartesian}}.
$$

### 4.1 RTN discrepancies

Use the Cartesian inertial state for one common reference basis:

$$
\hat{\mathbf R}=\frac{\mathbf r_C}{\|\mathbf r_C\|},\quad
\hat{\mathbf N}=\frac{\mathbf r_C\times\mathbf v_C}{\|\mathbf r_C\times\mathbf v_C\|},\quad
\hat{\mathbf T}=\hat{\mathbf N}\times\hat{\mathbf R}.
$$

Calculate $\Delta R=\Delta\mathbf r\cdot\hat{\mathbf R}$, $\Delta T=\Delta\mathbf r\cdot\hat{\mathbf T}$ and $\Delta N=\Delta\mathbf r\cdot\hat{\mathbf N}$ in metres. The runner reports signed mean, RMS, median, maximum absolute value and count for each component; it flags degenerate bases. Additional percentiles and group-specific summaries require further analysis. RTN is an established orbit-comparison frame, but these are product discrepancies, not precision-ephemeris truth errors ([Kelso, 2007](https://celestrak.org/publications/aas/07-127/AAS-07-127.pdf)).

For $n$ valid comparisons, the component RMS and signed bias are $\mathrm{RMS}_R=\sqrt{\sum_{i=1}^{n}\Delta R_i^2/n}$ and $\mathrm{bias}_R=\sum_{i=1}^{n}\Delta R_i/n$; calculate the transverse and normal summaries identically. Report scene counts and grouping alongside them.

### 4.2 Three-dimensional WGS84 geodetic position

Convert both spacecraft positions to WGS84 Earth-fixed geodetic latitude, longitude and ellipsoidal height. Report signed latitude difference, wrapped longitude difference, $\Delta h=h_T-h_C$ and:

- **Surface geodesic separation:** WGS84 ellipsoid distance between the two latitude/longitude locations. It is a 2D surface measure ([Karney, 2013](https://doi.org/10.1007/s00190-012-0578-z)). The subsatellite locations use the WGS84 ellipsoid-normal convention, not a geocentric radial projection.
- **Exact 3D separation:** $d_{3D}=\|\mathbf r_{T,E}-\mathbf r_{C,E}\|$ in metres, using the two Earth-fixed spacecraft positions at the same epoch.

For geodetic subsatellite points $g_C=(\phi_C,\lambda_C,0)$ and $g_T=(\phi_T,\lambda_T,0)$, the inverse ellipsoidal geodesic gives surface distance $d_g$ and initial bearing $\alpha$ from $g_C$ to $g_T$. The reported distance-and-bearing components are

$$
d_g=\operatorname{distance}_{\mathrm{WGS84}}(g_C,g_T),\qquad
\Delta E_g=d_g\sin\alpha,\qquad \Delta N_g=d_g\cos\alpha.
$$

They are polar components of the surface displacement using the initial bearing, not the east/north components of the 3D Earth-fixed chord. When the surface points coincide, the reported components are zero and the bearing is undefined. MATLAB's geodesic distance operates on the specified reference ellipsoid ([MathWorks, geodesics](https://www.mathworks.com/help/map/great-circles-geodesics-and-rhumb-lines.html)).

For $n$ valid comparisons, report $\mathrm{RMS}_{3D}=\sqrt{\sum_{i=1}^{n}d_{3D,i}^{2}/n}$, the distribution of surface separation and signed height differences, and sample counts. Do not compute Euclidean distance directly from mixed degree/metre coordinates or call $\sqrt{d_{\mathrm{surface}}^2+\Delta h^2}$ exact. These coordinates compare **orbital products only**; they are not matched to the image’s geodetic centre.

## 5. Footprint and potential-swath metrics

Let $P$ be the published polygon and $Q$ either orbit-based prediction. For the **same scene and common assumptions**, calculate $I=A(P\cap Q)$. The implementation projects both polygons into a common WGS84 ellipsoidal Lambert azimuthal equal-area plane, using the first reference-boundary point as projection origin, and calculates areas and local projected boundary distances. The origin is a numerical coordinate choice, not a fitted pointing direction. Handle antimeridian crossings, holes and invalid geometry.

| Measure | Calculation |
|---|---|
| Intersection | $I$ in km²: shared geometric area. |
| Published coverage | $I/A(P)$. |
| Predicted coverage | $I/A(Q)$. |
| Intersection over union | $I/A(P\cup Q)$. |
| Symmetric difference and area ratio | $A(P\triangle Q)$ and $A(Q)/A(P)$. |
| Boundary distance | Directed median and 95th-percentile distances in metres in both directions. |

Thus $A(P\cup Q)=A(P)+A(Q)-I$ and $A(P\triangle Q)=A(P)+A(Q)-2I$. The Cartesian-versus-TLE model comparison reuses these metrics with the TLE-predicted footprint as reference $P$ and the Cartesian prediction as $Q$; in that comparison, the CSV's `PublishedCoverage` field means **TLE-model coverage**, not coverage of a published scene.

For evenly spaced boundary samples $X_P$ and $X_Q$ in the projected plane, define the directed nearest-boundary distances and per-comparison symmetric summary as

$$
d_{P\rightarrow Q}(x)=\min_{y\in\partial Q}\lVert x-y\rVert_2,\qquad
B_{95}=\max\!\left\{Q_{0.95}(d_{P\rightarrow Q}),\,Q_{0.95}(d_{Q\rightarrow P})\right\}.
$$

The implementation samples by projected boundary arc length, at approximately 250 m by default, measures each sample to the nearest boundary segment, and uses a linearly interpolated sample percentile. Boundary distances are **local projected approximations**, not ellipsoidal geodesics. Check boundary and ray-sampling convergence. A summary across scenes reports the median of the individual $B_{95}$ values, not a pooled 95th percentile. Valid disjoint polygons have zero IoU and valid boundary distances; invalid or zero-area polygons are flagged. Geometric overlap is not cloud-free usable coverage, which requires masks ([Planet, usable-data masks](https://docs.planet.com/data/imagery/udm/)).

**Longer swept swaths:** published-scene coverage $A(P\cap Q)/A(P)$ remains useful, but IoU or prediction coverage is unfair when $Q$ extends far beyond the scene. The runner uses the same explicitly specified sampled interval for both products. For future analysis, predeclare a spatial area of interest and, if needed, clip both predictions and the published polygon to that same area; this clipping is **not implemented**. Compare IoU and prediction coverage only on comparable support, and separately report area outside it. A scene-level published polygon cannot itself be temporally clipped without suitable pixel/line timing. Do not use clipping to fit or align to the published centre.

The runner reports paired Cartesian–TLE scores per matched combination and a pooled median for each sign and comparison. Grouping by satellite, day or strip requires additional analysis. The current options allow separate runs with different matching tolerances, pointing signs and angles, detector roll, proxy dimensions and sampled-sweep parameters. Changing a matching tolerance filters candidates; it does **not** impose an acquisition time bias. A common time-tag bias, alternative force models and terrain scenarios remain unimplemented. A deterministic potential-swath envelope is not a confidence interval without justified probability distributions. Freeze assumptions before evaluation; calibrate any sensor parameters on separate scenes and do not fit either prediction to its published footprint. Because Planet orbit and imagery products may share source information, a closer score is conditional consistency, not independent proof of better absolute orbit accuracy.

## 6. Implementation status and planned outputs

The MATLAB entry point `run_footprint_study` takes the options from `footprint_study_config`. It writes a match inventory, analysis status, per-match orbital and footprint metrics, stored model geometries, a report and an example figure. Archive coverage is also written when available. The implemented baseline is two-body Cartesian propagation and SGP4, with a snapshot scene proxy or a user-parameterized swept scenario. It is not the Foster orbit fit. See the [main README](../README.md) for setup and the run command.

Terrain correction, calibrated attitude and detector geometry, a paper-inspired drag scenario, full sensitivity studies and independent frame, identity and SGP4 verification remain research tasks. XML asset retrieval is not automated. A successful run is not itself validation: inspect match failures and provenance, and present only actual analysis outputs as research results.

## References

- Foster, C., Hallam, H. and Mason, J. (2015). *Orbit Determination and Differential-drag Control of Planet Labs Cubesat Constellations*. [arXiv:1509.03270](https://arxiv.org/abs/1509.03270).
- Vallado, D. A., Crawford, P., Hujsak, R. and Kelso, T. S. (2006). *Revisiting Spacetrack Report #3*. [DOI: 10.2514/6.2006-6753](https://doi.org/10.2514/6.2006-6753).
- Kelso, T. S. (2007). *Validation of SGP4 and IS-GPS-200D Against GPS Precision Ephemerides*. [AAS 07-127](https://celestrak.org/publications/aas/07-127/AAS-07-127.pdf).
- Karney, C. F. F. (2013). *Algorithms for geodesics*. [Journal of Geodesy 87, 43–55](https://doi.org/10.1007/s00190-012-0578-z).
- Aati, S. and Avouac, J.-P. (2020). *Optimization of Optical Image Geometric Modeling, Application to Topography Extraction and Topographic Change Measurements Using PlanetScope and SkySat Imagery*. [Remote Sensing 12, 3418](https://doi.org/10.3390/rs12203418).
- Mueting, A. and Bookhagen, B. (2024). *Tracking slow-moving landslides with PlanetScope data: new perspectives on the satellite’s perspective*. [Earth Surface Dynamics 12, 1121–1143](https://doi.org/10.5194/esurf-12-1121-2024).
- Sienkiewicz, N. et al. (2024). *Developing small satellite ground support software for orbit tracking and target acquisition of the HARP cubesat*. [Frontiers in Remote Sensing](https://doi.org/10.3389/frsen.2024.1474600).
- Planet Labs PBC (2026). [Imagery Product Specifications](https://assets.planet.com/docs/Planet_Combined_Imagery_Product_Specs_letter_screen.pdf); [PSScene metadata](https://docs.planet.com/data/imagery/planetscope/psscene/); [public orbital ephemerides](https://ephemerides.planet-labs.com/).
- NASA NAIF (current documentation). [Surface-intercept geometry](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/sincpt_c.html).
- MathWorks (current documentation). [MATLAB propagateOrbit](https://www.mathworks.com/help/aerotbx/ug/propagateorbit.html).
