// the 'make.do' file is automatically created by 'github' package.
// execute the code below to generate the package installation files.
// DO NOT FORGET to update the version of the package, if changed!
// for more information visit http://github.com/haghish/github

*##s

cap program drop getfiles
program define getfiles, rclass

args mask

local f2add: dir . files "`mask'", respectcase

foreach a of local f2add {
	local as "`as' `a'"
}
local as = trim("`as'")
local as: subinstr local as " " ";", all

return local files = "`as'"
end

if ("`c(username)'" == "wb384996") {
    cd "c:/Users/`c(username)'/OneDrive - WBG/WorldBank/DECDG/PIP/pip"
}
else {
    // Damian, add your path here.. 
}

getfiles "*.ado"
local as = "`r(files)'"

getfiles "*.sthlp"
local hs = "`r(files)'"

getfiles "*.mata"
local ms = "`r(files)'"


getfiles "*.dlg"
local ds = "`r(files)'"

getfiles "*.dta"
local dtas = "`r(files)'"


local toins  "`as';`hs';`ms';`ds';`dtas'"
disp "`toins'"


make pip, replace toc pkg                                  ///  readme
	version(0.0.0.9000)                                   ///
    license("MIT")                                         ///
    author("R.Andres Castaneda, Damian Clarke")            ///
    affiliation("The World Bank, The University of Chile and The University of Exeter")                          ///
    email("acastanedaa@worldbank.org, dclarke@fen.uchile.cl")                     ///
    url("")                                                ///
    title("Suite to Cache output of Stata commands") ///
    description("")        ///
    install("`toins'")                                     ///
    ancillary("")                                                         

*##e
