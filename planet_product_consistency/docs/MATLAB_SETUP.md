# Install, activate and run MATLAB from Windows PowerShell

This guide prepares the MATLAB-only workflow in this repository for execution
from a Windows terminal. It covers tests and the real-data research workflow.
The examples use PowerShell; paths and license-server addresses are examples
that you must replace with your own.

## 1. What needs to be licensed?

You need a working MATLAB installation and a license that the **Windows account
and execution environment running the command** can use. Depending on the license,
MATLAB may use an activated local license, a MathWorks Account sign-in or a network
license server. A MathWorks password is not an input to this repository or to the
batch commands below. Sign in through MathWorks' own installer or activation UI;
do not put passwords, activation keys or license files in the repository or chat.

| Workflow | MATLAB products and other requirements |
|---|---|
| PlanetScope acquisition quick look | Base MATLAB with Java, local archives, a Planet API key and Internet access; Aerospace and Mapping toolboxes are not required |
| Source/pairing audit | MATLAB with Java; local archives or network access; no orbital evaluation |
| Real pilot / full study | MATLAB R2024b or newer with Java, installed Aerospace Toolbox, installed Mapping Toolbox and observed Earth-orientation data; network access if the source cache is incomplete |

`propagateOrbit`, used by the real-data workflow, was introduced in R2024b.
MATLAB Runtime alone is for compiled applications; this repository provides
MATLAB source files and requires MATLAB itself. See MathWorks'
[`propagateOrbit` documentation](https://www.mathworks.com/help/aerotbx/ug/propagateorbit.html)
and [MATLAB Runtime documentation](https://www.mathworks.com/help/compiler/matlab-runtime.html).

## 2. Install MATLAB and toolboxes

1. Check that you have access to a MATLAB license. For a university or employer
   license, use the account and license information supplied by your institution;
   contact its license administrator if the correct license is not available.
2. Sign in to the official [MathWorks Downloads page](https://www.mathworks.com/downloads/)
   and download the Windows installer for a licensed release **R2024b or newer**.
3. Run the installer, sign in when prompted, select the appropriate license and
   install **MATLAB**. For the real-data study, also select **Aerospace Toolbox**
   and **Mapping Toolbox** if they are available under that license.
4. Complete the installer and activation prompts. If MATLAB was already installed,
   confirm that the two toolboxes are installed for the same release.

MathWorks documents the supported interactive procedure in
[Download and Install MATLAB](https://www.mathworks.com/help/install/ug/install-products-with-internet-connection.html).
An organization may instead use a network license or a managed installation;
follow its administrator's instructions rather than assuming a personal license.

## 3. Activate or connect the license

Open MATLAB once under the Windows account that will run the terminal commands.
Complete any MathWorks sign-in and activation prompts for your license. If manual
activation is needed, search the Start menu for **Activate MATLAB** and choose
the matching release. Alternatively, run the installed activation client from
PowerShell, substituting your release and installation directory:

```powershell
& "C:\Program Files\MATLAB\R2026a\bin\win64\MathWorksProductAuthorizer.exe"
```

This opens MathWorks' interactive activation client; complete its sign-in and
license-selection screens yourself. It is not a password-taking terminal command.
For offline activation or a license-file-based setup, follow the
[MathWorks activation guide](https://www.mathworks.com/help/install/ug/activate-matlab-installation-manually.html)
and your license administrator's instructions. A network license generally needs
access to the institution's license server. Some sign-in-based licenses need
Internet access; whether MATLAB works offline depends on the license type.

If your administrator explicitly supplies a network license-server address or
license-file path, MATLAB can be started with `-c`. For example, after defining
`$matlabExe` in the next section:

```powershell
& $matlabExe -wait -c "27000@your-license-server" -batch "disp(version)"
```

Replace the placeholder with the value provided by your administrator. The `-c`
option overrides the normal license search for that invocation; omit it for a
working default license. See [Locate Your License File](https://www.mathworks.com/help/install/ug/locate-matlab-license-files.html).

MathWorks also documents [noninteractive installation](https://www.mathworks.com/help/install/ug/install-noninteractively-silent-installation.html)
for managed environments using the appropriate installation files and license
information. The exact setup depends on the license and is not required for the
interactive installation above.

## 4. Find MATLAB in PowerShell

Open a **new** PowerShell window as the same Windows user who activated MATLAB.
First check whether `matlab.exe` is already on the command search path:

```powershell
Get-Command matlab -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty Source
```

If a path is printed, save it for the commands below:

```powershell
$matlabExe = (Get-Command matlab -CommandType Application).Source
```

If no path is printed, MATLAB might be installed without being on `PATH`. Look for
installed releases and set the executable path explicitly. Replace `R2026a` with
the release actually installed; another installation directory is possible:

```powershell
Get-ChildItem -LiteralPath (Join-Path $env:ProgramFiles 'MATLAB') -Directory -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName

$matlabExe = 'C:\Program Files\MATLAB\R2026a\bin\matlab.exe'
Test-Path -LiteralPath $matlabExe
```

Continue only when `Test-Path` returns `True`. If the standard directory is empty,
ask your administrator for the installation path or install MATLAB. You can use
the explicit executable path without changing the system `PATH`.

Check startup and licensing:

```powershell
& $matlabExe -wait -batch "disp(version); fprintf('Java JVM available: %d\n',usejava('jvm')); ver"
$LASTEXITCODE
```

A successful command prints the release, installed products and `Java JVM
available: 1`, then returns exit code `0`. The repository uses Java for SHA-256
provenance; do **not** start it with `-nojvm`.

### Configure Java for MATLAB R2026b and later

MATLAB R2026b no longer includes a Java runtime by default. If the check shows
`Java JVM available: 0` or Java calls fail with `MATLAB:Java:JavaNotFound`,
install a supported OpenJDK runtime before running this repository. MathWorks
documents the change and supported versions in its
[OpenJDK compatibility table](https://www.mathworks.com/support/requirements/openjdk.html).

The MathWorks-supported option is to open MATLAB's Add-On Explorer, search for
**MATLAB Support for OpenJDK**, and install it. After installation, run
`jenv -clear` in MATLAB to remove an existing per-user Java override, then
restart MATLAB or its VS Code session. A compatible external Adoptium or Corretto
runtime is another supported option; configure its installation directory using
`jenv("JRE_path")` in MATLAB, or `matlab_jenv` from the operating-system
prompt. Replace the example paths with your installed MATLAB and runtime paths:

```powershell
& 'C:\Program Files\MATLAB\R2026b\bin\matlab_jenv.bat' 'C:\path\to\supported-jre'
& $matlabExe -wait -batch "fprintf('JVM available: %d\n',usejava('jvm')); java.security.MessageDigest.getInstance('SHA-256'); disp(version('-java'));"
$LASTEXITCODE
```

`matlab_jenv` sets the Java path for future MATLAB sessions for the current
user; it does not change the path used by other applications. See
[Configure Your System to Use Java](https://www.mathworks.com/help/matlab/matlab_external/configure-your-system-to-use-java.html)
and [matlab_jenv](https://www.mathworks.com/help/matlab/ref/matlab_jenv.html).
The SHA-256 call above verifies that MATLAB can actually use Java; merely
detecting a configured runtime is not a complete test.

On Windows, `-batch` runs the MATLAB statement noninteractively and exits. The
additional `-wait` makes the terminal wait for the process and its exit status;
check `$LASTEXITCODE` immediately after the MATLAB command. See the
[MATLAB Windows startup reference](https://www.mathworks.com/help/matlab/ref/matlabwindows.html).
MathWorks notes that Windows batch execution can still require a basic graphical
environment, even though it does not open the MATLAB Desktop. See its
[Windows batch support note](https://www.mathworks.com/matlabcentral/answers/2184918-can-i-run-matlab-from-the-command-line-without-a-gui-on-windows).

## 5. Check toolbox functions and license availability

On the tested R2026b Update 1 installation, `propagateOrbit` and `tleread`
are P-code files, so MATLAB reports `exist(name,'file') == 6` rather than 2.
The repository accepts M-files, MEX files and P-code as installed functions.

The same installation rejects the documented explicit
`OutputCoordinateFrame="icrf"` option. The SGP4 wrapper instead omits that
option and uses the documented ICRF default. A local smoke check confirmed
that the default and the runtime-accepted `"inertial"` option produced
identical output for one Planet TLE; this is not an independent SGP4 or
reference-frame accuracy validation. Research-mode validation gates remain
in force. See the MathWorks [`propagateOrbit` reference](https://www.mathworks.com/help/aerotbx/ug/propagateorbit.html).

For the **real-data pilot**, run:

```powershell
& $matlabExe -wait -batch "ver; fprintf('propagateOrbit: %s\n',which('propagateOrbit')); fprintf('tleread: %s\n',which('tleread')); fprintf('dcmeci2ecef: %s\n',which('dcmeci2ecef')); fprintf('distance: %s\n',which('distance')); fprintf('wgs84Ellipsoid: %s\n',which('wgs84Ellipsoid')); fprintf('Aerospace entitlement: %d\n',license('test','Aerospace_Toolbox')); fprintf('Mapping entitlement: %d\n',license('test','MAP_Toolbox'));"
$LASTEXITCODE
```

`ver` lists installed products; each function line should show a path. A license
test result of `1` indicates that the license contains the named feature. It does
**not** prove that the toolbox is installed or that a network license seat can
be checked out. A `0` or missing function path requires attention before the
real-data run. See the [MathWorks license function](https://www.mathworks.com/help/matlab/ref/license.html).

You can also test the required installed functions explicitly:

```matlab
assert(exist('propagateOrbit','file') == 2, 'Aerospace Toolbox is missing.')
assert(exist('wgs84Ellipsoid','file') == 2, 'Mapping Toolbox is missing.')
```

If either function is absent, install the corresponding toolbox for the same
MATLAB release using the MathWorks installer, subject to your license.

To test an actual checkout, run the following **only when you are ready to use
those toolbox licenses**; the MATLAB process exits after the check:

```powershell
& $matlabExe -wait -batch "[a,am]=license('checkout','Aerospace_Toolbox'); [m,mm]=license('checkout','MAP_Toolbox'); fprintf('Aerospace checkout=%d %s\n',a,am); fprintf('Mapping checkout=%d %s\n',m,mm); assert(a && m,'Required toolbox checkout failed');"
$LASTEXITCODE
```

If a license exists but checkout fails, consult the message and your license
administrator; seats may be in use or the server may be unavailable. License
entitlement, installed functions and successful checkout are separate checks.

## 6. Run tests from the terminal

Change to the **repository root** containing `run_study.m`. Replace the
example path, then run the test suite:

```powershell
Set-Location -LiteralPath 'C:\path\to\planet_product_consistency'
& $matlabExe -wait -batch "run_tests"
$LASTEXITCODE
```

Inspect the displayed test results as well as the exit code. `run_tests` fails
the batch command when tests fail, but some optional tests may be marked
incomplete or skipped when dependencies are unavailable. A zero exit code alone
does not establish that Aerospace SGP4 or real data were tested.

## 7. Run the research analysis from the terminal

Follow the [research protocol](RESEARCH_PROTOCOL.md) to review identity
intervals, frame policy and independent SGP4 evidence. In a MATLAB script such
as `my_research_run.m` in the repository folder, call `startup_consistency`,
create `cfg = study_config("research")`, apply the reviewed settings, and call
`ctx = run_study(cfg)`. Then invoke your configured script from PowerShell:

```powershell
& $matlabExe -wait -batch "my_research_run"
$LASTEXITCODE
```

The terminal prints the timestamped run directory and report path. A successful
publication creates `results/RUN_REPORT.md`; if publishing that stable copy
fails, the terminal instead identifies the current run's original report.
Inspect the run's `stage_log.csv`, `RUN_REPORT.md` and sample counts; process
completion alone does not prove complete coverage or a nonempty primary sample.

To choose a different archive root or run offline, set `cfg.paths.raw` and
`cfg.paths.eop` to your existing files, set `cfg.download.enabled=false`, and
optionally set `cfg.download.snapshotIdentity=false` when no identity snapshot
is cached. The roster is still used for identity matching. One guard date before
and after the selected interval should be available; missing files are reported.

## 8. Troubleshooting and execution environment

| Symptom | What to check |
|---|---|
| `matlab` is not recognized | Use the absolute `matlab.exe` path as `$matlabExe`; check the installation release and directory. |
| MATLAB starts but activation/login fails | Complete activation through MathWorks as the same Windows user; check Internet or license-server access and ask your license administrator. |
| Java runtime is missing | Configure a compatible OpenJDK runtime, restart MATLAB, and repeat the Java check in section 4. |
| Toolbox function is missing | Check `ver` and the function paths above; install the licensed toolbox into the selected MATLAB release. |
| Toolbox checkout fails | Check license entitlement, seat availability and server access. A successful `license('test',...)` alone does not guarantee checkout. |
| Real-data analysis fails | Confirm Aerospace and Mapping licenses, source-cache paths, observed EOP coverage and the run's `RUN_FAILED.txt` / `stage_log.csv`. |
| Batch exits successfully but the report has no numerical results | Inspect archive/identity coverage and primary successful-pair counts; the audit profile stops before orbital metrics. |
| Latest report remains unchanged | Inspect `ctx.latestReportStatus`, the timestamped run report and `REPORT_PUBLISH_FAILED.txt`; a failed run or an existing unowned/read-only latest report is not overwritten. |

An installed and activated MATLAB on another computer is not automatically
available to the terminal or assistant working in this workspace. For an agent to
execute the commands, `matlab.exe`, its license and required toolboxes must be
accessible to the actual process environment and Windows account running them.
If MATLAB runs elsewhere, run the commands there with this project and its data,
or arrange an appropriately licensed shared execution environment. Do not send
account passwords or license files to the assistant.

## 9. Use MATLAB in Visual Studio Code

Install the [MATLAB extension by MathWorks](https://marketplace.visualstudio.com/items?itemName=MathWorks.language-matlab)
and open this repository as a VS Code folder. The extension can find MATLAB on
the system PATH, or you can set **MATLAB: Install Path** in VS Code settings to
the MATLAB installation directory, for example:

```text
C:\Program Files\MATLAB\R2026b
```

This setting is the installation directory, not `bin\matlab.exe`. Use the
directory for the release installed on your machine. Open any MATLAB file and
run it with VS Code's MATLAB extension, or enter commands in the extension's
MATLAB terminal. See the [extension setup and execution instructions](https://github.com/mathworks/MATLAB-extension-for-vscode).

The extension does not supply a MATLAB license. If MATLAB reports that it cannot
find a license, activate the installation under the Windows account that will run
it, or configure the network license supplied by your institution. If appropriate,
the extension's **MATLAB: Sign In** setting enables browser-based sign-in.

For an automated terminal check, run the installed executable directly:

```powershell
& 'C:\Program Files\MATLAB\R2026b\bin\matlab.exe' -wait -batch "disp(version)"
$LASTEXITCODE
```

The repository's `.env` holds the Planet API key; MATLAB activation and license
configuration are handled separately by MathWorks and your license administrator.
