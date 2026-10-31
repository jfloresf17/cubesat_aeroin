# PlanetScope acquisition quick-look inspector

The MATLAB quick-look inspector searches Planet's PSScene catalogue for scenes
acquired close to a Cartesian state for the same satellite. It is an inventory
and screening tool for selecting real image acquisitions for further study. It
does not calculate image-derived satellite positions, RTN differences or orbit
accuracy.

## Requirements

- MATLAB installed and licensed on the machine running the command. See the
  [MATLAB setup guide](MATLAB_SETUP.md) for Windows terminal setup.
- A compatible Java runtime configured for MATLAB, used for source-file
  hashing. MATLAB R2026b no longer includes Java by default; see the
  [MATLAB setup guide](MATLAB_SETUP.md#configure-java-for-matlab-r2026b-and-later).
  The quick look does not require Aerospace or Mapping toolboxes.
- Internet access to the Planet Data API and a Planet API key associated with
  the account used for the search. Catalogue visibility, thumbnail availability
  and permission to download full imagery depend on that account.
- Local Planet Cartesian and TLE archives. The configured roster supplies names
  and identity-review labels where available; it does not restrict the search to
  its 36 candidate satellites. For the supplied cache, the existing files cover
  March–August 2026; choosing the 2026 calendar year does not create states for
  the missing months.

The current leap-second table is reviewed only through 2 September 2026.
Archives with native epochs beyond that validity require a reviewed table and
configuration before they can be used. Archive presence alone does not mean
all records parsed successfully; inspect `parse_log.csv`.

MATLAB can call the Planet API directly through its HTTPS functions. A Python
environment is not required. See Planet's [authentication](https://docs.planet.com/develop/authentication/)
and [Data API search](https://docs.planet.com/develop/apis/data/item-search/)
documentation.

## Set up the local .env file

Open the repository-root `.env` file in Notepad:

```powershell
notepad .env
```

If `.env` is missing, create it from the template first:

```powershell
Copy-Item -LiteralPath '.env.example' -Destination '.env'
```

Replace the placeholder with your Planet API key and save the file. The line
should have this form:

```text
PLANET_API_KEY=your_planet_api_key
```

The key is available in your Planet account's **My Settings** page. The
inspector reads `.env` from the repository root when it runs. The file is
ignored by Git but contains the key as plain text: keep it private and do not
include it in shared archives, screenshots, result tables or chat. An
already-set, nonempty `PLANET_API_KEY` in MATLAB's process environment takes
precedence over the file.

MATLAB itself must still be installed, activated and licensed for the account
running it; the Planet key does not install or authenticate MATLAB. Follow the
[MATLAB setup guide](MATLAB_SETUP.md) for that step.

## Alternative: set the key for one terminal session

To avoid saving the Planet key in a file, run the following PowerShell commands.
They read the key without displaying it and put it in an environment variable
inherited by MATLAB:

```powershell
$planetKeySecure = Read-Host 'Planet API key' -AsSecureString
$planetKeyPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($planetKeySecure)
try {
    $env:PLANET_API_KEY = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($planetKeyPtr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($planetKeyPtr)
    Remove-Variable planetKeySecure,planetKeyPtr
}
```

Start MATLAB from that **same PowerShell window**. An already-open MATLAB
process does not automatically inherit environment changes made later. The key
grants account access: do not put it in source files, screenshots, result tables
or chat. Close the PowerShell window, or remove the variable when finished:

```powershell
Remove-Item Env:PLANET_API_KEY
```

## Search a calendar year

From the repository folder in MATLAB:

```matlab
startup_consistency
opts = quicklook_config();
opts.StartUTC = datetime(2026,1,1,'TimeZone','UTC');
opts.EndUTC = datetime(2026,12,31,'TimeZone','UTC'); % Inclusive UTC date.
opts.TimeToleranceSeconds = 1;       % Scene-to-Cartesian window, in seconds.
opts.DownloadThumbnails = false;      % Optional: enable for a visual gallery.
result = quicklook_inspector(opts);
```

The configured default tolerance is **60 seconds**; the example requests the
study's **±1-second** candidate window. Both are adjustable exploratory filters,
not validated timing-accuracy requirements. A signed time
difference should be interpreted relative to the scene's reported acquisition
time, which is not automatically a verified centre-line time.

To start the default search from PowerShell after creating the `.env` file or
setting the session key and changing to the repository folder:

```powershell
matlab -wait -batch "startup_consistency; opts=quicklook_config(); quicklook_inspector(opts);"
$LASTEXITCODE
```

If `matlab` is not on `PATH`, use its full executable path as shown in the
[MATLAB setup guide](MATLAB_SETUP.md). A successful command returns exit code
zero; inspect the output and reported exclusions as well.

### Adjust paths, tolerance or previews

Use the configured defaults or set the paths before running:

```matlab
opts = quicklook_config();
opts.RawPath = 'D:\Planet\raw\daily';     % Flat or dated YYYY/MM tree.
opts.RosterPath = 'D:\Planet\roster.csv';
opts.ResultsPath = 'D:\Planet\quicklook_results';
opts.TimeToleranceSeconds = 30;
opts.DownloadThumbnails = false;
result = quicklook_inspector(opts);
```

The path values are examples; replace them with your own. Enable thumbnails to
inspect downsampled previews when the account and service permit them. Thumbnails
are not full-resolution source images. Consult Planet's [item preview
documentation](https://docs.planet.com/develop/apis/data/items/) for access and
size details.

For a metadata-only search using the default paths, disable preview downloads:

```matlab
opts = quicklook_config();
opts.DownloadThumbnails = false;
result = quicklook_inspector(opts);
```

This still searches the catalogue and saves the matching records and reports.

## Review the results

Each run creates a new timestamped `results/quicklook_<timestamp>/` directory
under the configured `ResultsPath`. Open its `index.html` in a browser for the
quick-look view and `QUICKLOOK_REPORT.md` for the search and matching summary.
After the catalogue search and matching finish, the inspector saves the tables,
report, gallery and MATLAB results before requesting thumbnails. When previews
are enabled, their initial status is `PENDING`; the preview status, report,
gallery and MATLAB results are updated after downloads finish. If the download
stage is interrupted, the saved search and matches remain available, but the
preview status may still show `PENDING`.

| File | Contents |
|---|---|
| `matches.csv` | Every qualifying scene × Cartesian-state × same-day-TLE combination, with time differences, selected metadata and source provenance |
| `candidate_scenes.csv` | Returned scene metadata, including scenes that do not produce a complete match |
| `scene_status.csv` | Matching status and counts for each returned scene |
| `preview_status.csv` | Thumbnail retrieval status for matched scenes |
| `archive_inventory.csv` | Discovered source files, hashes, receipt checks and parsing status |
| `archive_coverage.csv` | Availability of state and TLE archives by UTC archive date |
| `parse_log.csv` | Individual native-record parsing issues |
| `quicklook_results.mat` | MATLAB tables and run information for further inspection |
| `thumbnails/` | Downloaded preview images, when enabled and available |

For the signed differences, `SceneMinusState_s` and `SceneMinusTLE_s` are the
scene acquisition time minus the native state or TLE epoch, respectively.
Check the report and status tables before treating the output as complete.

The catalogue metadata includes the reported footprint, viewing angle and
satellite azimuth when Planet provides them. The catalogue search does not
download a scene's separate XML product metadata; fields such as `centerOf/pos`
and `incidenceAngle` must not be assumed present in the search response. An
image-centre geometry study may need additional permitted metadata assets.

## Matching and interpretation

The inspector searches all satellite hardware identifiers in the local native
state format, not only the 36-satellite study roster. It queries scenes in
merged short time windows around the available states, so the goal is every
scene that could meet the time filter, not every catalogue scene in 2026.
For each batch of windows, the API search is limited to satellite identifiers
with state windows overlapping that batch. Returned scenes are catalogue
**candidates**, not necessarily matches: the inspector checks each candidate
against its own satellite's states and same-day TLE records after retrieval.
Invalid records are reported rather than assumed to represent other spacecraft.
The inspector retains qualifying combinations rather than silently keeping just
the nearest match. A match requires:

1. A matching native satellite hardware identifier in the scene, Cartesian
   state and TLE header. Any identity conflicts are flagged.
2. An absolute scene-to-Cartesian time difference no greater than the configured
   tolerance. `SceneMinusState_s` is the scene acquisition time minus the state
   epoch; positive means the reported scene time is later.
3. A TLE **native epoch** on the same UTC calendar date as the scene. This is a
   date test; it is not the baseline study's 1 ms TLE–Cartesian epoch test, nor
   does the archive filename prove the TLE's availability time.

Multiple states, TLEs or scenes may therefore produce multiple rows. The number
of matching rows is a count of combinations, not a count of unique scenes. Use scene,
strip, state and TLE identifiers to assess repeated or related records. Where
the roster has a matching identity it supplies the available review label; its
candidate historical mappings remain subject to review before research claims
are made. Absence from the roster does not, by itself, exclude a native ID.

Planet's Data API paginates search results. A complete inventory must process
all returned pages and clearly report failed or incomplete searches; a partial
response is not evidence that there are no further matches.

## Troubleshooting

| Symptom | Check |
|---|---|
| Key is missing | Add `PLANET_API_KEY` to the repository-root `.env`, or set it in the environment that starts MATLAB. A nonempty environment value takes precedence. |
| HTTP 401 or 403 | Check the API key and the account's catalogue or asset permissions. |
| No matches | Check satellite identifiers, source archive coverage, scene/state epochs, the UTC-day TLE condition and the time tolerance. |
| Some previews fail | Check thumbnail permissions and the reported per-item error; a missing thumbnail is not proof that the scene does not exist. |
| Search is interrupted or rate-limited | Inspect the reported search status and retry; do not interpret incomplete searches as exhaustive. |

The metadata and previews support acquisition selection. They are not an
independent spacecraft-position truth reference and do not by themselves prove
the precision of an image-derived subsatellite point.
