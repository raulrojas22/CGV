# Third-party notices

CGeV Desktop bundles open-source components. Their copyright notices and license files remain in the packaged application or runtime where supplied by the upstream project.

- [Electron](https://www.electronjs.org/) and the Electron Node.js dependencies are distributed under their respective open-source licenses. The exact JavaScript dependency tree is recorded in `desktop/package-lock.json`.
- [R](https://www.r-project.org/) 4.4.3 is distributed under the GNU General Public License. The bundled R distribution retains its `COPYING` file.
- [CRAN](https://cran.r-project.org/) and [Bioconductor](https://bioconductor.org/) packages use package-specific open-source licenses recorded in each installed package's `DESCRIPTION` and license files.
- [LASTZ](https://github.com/lastz/lastz) 1.04.52 is distributed under the MIT License, copyright Robert S. Harris. Its license is included in [licenses/LASTZ-LICENSE.txt](licenses/LASTZ-LICENSE.txt).
- [mman-win32](https://github.com/alitrack/mman-win32) is used to build the native Windows LASTZ executable and is distributed under its upstream MIT License. Its notice is included in [licenses/mman-win32-LICENSE.txt](licenses/mman-win32-LICENSE.txt).
- [NSIS](https://nsis.sourceforge.io/) is used by electron-builder to produce the Windows installer under its upstream license.

CGeV itself is distributed under the repository's MIT License. This notice is a summary and does not replace the license text shipped with each component.
