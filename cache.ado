/* ==================================================
project:       Stata client to cache results of other commands
Author:        R.Andres Castaneda 
E-email:       acastanedaa@worldbank.org
url:           
Dependencies:  The World Bank
----------------------------------------------------
Creation Date:     4 May 2023 - 09:35:43
Modification Date:   
Do-file version:    01
References:          
Output:             
==================================================*/

/*==================================================
0: Program set up
==================================================*/
program define cache, rclass properties(prefix)
	version 16.1

	//========================================================
	//  SPLIT	
	//========================================================


	// I think we need to correct for commands like "cache: merge 1:1 ..." below
	* Split the overall command, stored in `0' in a left and right part.
	gettoken left right : 0, parse(":")


	if ("`left'" == "")  {
		dis "{err: make sure you follow this syntax}:"
		dis _n "{cmd: cache {it:[subcmd] [, options]}: command}"
		error 197
	}

	// remove first : in each part (left part should not have any)
	cache_utils clean_local, text("`left'")
	local left = "`r(text)'"

	cache_utils clean_local, text("`right'")
	local right = "`r(text)'"

	// Get command and properties
	if (ustrregexm("`right'", "^([A-Za-z0-9_]+)(.*)")) {
		local cmd =  ustrregexs(1)
	}
	local cmd_properties : results `cmd'
	local cmd_results : results `cmd'

	local origframe = c(frame)

	//========================================================
	// Syntax of left part
	//========================================================
	* Regular syntax parsing for cache
	local 0 : copy local left
	syntax [anything(name=subcmd)]   ///
	[,                   	   /// 
		dir(string)              ///  directory to save cache (already there).  Can get a global that users set.
		project(string)          ///  folder destined to cache, and within dir they want projects
		prefix(string)           ///
		noDATA                   ///
		pause                    ///
		clear                    ///
		replace                  ///  check if this does something else
		force                    ///  force says to re-run even if the cache is there
	] 


	//========================================================
	// Set up and defenses
	//========================================================

	* pause
	if ("`pause'" == "pause") pause on
	else                      pause off
	set checksum off

	// Set dir if not selected by user
	if ("`dir'" == "") {
		cache_setdir
		local dir = "`r(dir)'"
	}

	if ("`project'" == "") {
		local project = "_default"
	}

	// Add project to dir... I still don't know what the best way is
	// probably local dir = "`dir'" + "\`project'"
	// makedir "`dir'"

	//========================================================
	// HASHING and SIGNATURE
	//========================================================

	// hash command --------------------------
	cache_hash get,  cmd_call("`right'")
	local cmd_hash = "`r(chhash)'"
	return local cmd_hash = "`cmd_hash'"

	//  Data signature --------------------------
	if ("`data'" == "") {
		qui datasignature 
		local datasignature = "`r(datasignature)'"
		return local datasignature = "`datasignature'"
	}

	//  combine both parts --------------------------
	cache_hash get,  cmd_call("`cmd_hash'`datasignature'") prefix("`prefix'")
	local call_hash = "`r(chhash)'"
	return local call_hash = "`call_hash'"

	//========================================================
	// Find cache files and load
	//========================================================
	// Find log --------------------------
	cap findfile `call_hash'.smcl, path(`dir')
	if _rc==0  {
		local logfound = 1
		local log = r(fn)
	}
	else local logfound = 0

	// Find files --------------------------
	local files: dir "`dir'" files "`call_hash'*.dta", respectcase
	local loadfiles = 0

 	if length(`"`files'"') != 0 {
		//dis "Cache found"

		// Generate frames to load returns
		foreach n in scalars macros matrices {
			tempname `n'_results
			frame create ``n'_results'
		}
		local ematrix
		local rmatrix

		// use files
		foreach file of local files {
			local rfile_name = subinstr("`file'", "`call_hash'", "", 1)
			if "`rfile_name'"==".dta" {
				local loadfiles = 1
			}
			else {
			    * Extract the first letter (e, r, s)
			    if ustrregexm("`rfile_name'", "^_([ers])_")==1 local first_letter = ustrregexs(1) 
				if "`first_letter'"=="r" local treturn = "return"
				else                     local treturn = "`first_letter'return"

			    * Extract the type (macros, matrix, scalars)
			    if 	ustrregexm("`rfile_name'", "^[^_]*_[^_]*_([a-z]+)") local type = ustrregexs(1) 

			    * Extract any extra details after matrix (if present)
			    if ustrregexm("`rfile_name'", "_matrix_([A-Za-z0-9_]+)") local extra = ustrregexs(1) 
    
				//========================================================
				// load and export to lists
				//========================================================
				if "`type'"=="matrix" {
				    cwf	`matrices_results'
					qui use `dir'/`call_hash'`rfile_name', clear
					qui ds _rownames, not
					local savvars = r(varlist)
					mkmat `savvars', matrix("`extra'") rownames(_rownames)
			
					// Now grab colnames from labels
					local colnames
					foreach var of varlist `savvars' {
						local colname: variable label `var'
						local colnames = "`colnames' `colname'"
					}
					matname `extra' `colnames', columns(.) explicit

					//Save matrix in list for later processing
					local `first_letter'matrix ``first_letter'matrix' `extra'
					cwf `origframe'
					//Sets extra as empty to avoid passing forward matrix
					local extra = ""
				}
				else if "`type'"=="scalars"|"`type'"=="macros" {
					//Get a list of types and names to avoid re-searching below
				}
			}
		}	

		//========================================================
		// Export matrices and ereturn post
		//========================================================
		if length("`ematrix'`rmatrix'")!=0 {
			if length("`ematrix'")!=0 {
				local estpost = 0
				foreach matrix of local ematrix {
					if inlist("`matrix'", "b", "V", "Cns") {
						local estpost = 1
					}
				}

				// Post estimation command
				if `estpost' == 1 {
					if `loadfiles' == 1 {
						cwf	`origframe'
						qui use `dir'/`call_hash', clear
						ereturn post b V, esample(_funcvar) 
					}
					else {
						ereturn post b V
					}
				}
			}
			// Return other ematrices
			foreach matrix of local ematrix {
				cwf	`matrices_results'
				if !inlist("`matrix'", "b", "V", "Cns") {
					cache_ereturn `matrix', name(`matrix') type("matrix")
				}
			}
			// Return rmatrices
			foreach matrix of local rmatrix {
				cwf	`matrices_results'
				return matrix `matrix'=`matrix' 
			}
			cwf	`origframe'
		}


		//========================================================
		// Export scalars and macros
		//========================================================
		foreach file of local files {
			local rfile_name = subinstr("`file'", "`call_hash'", "", 1)
			if "`rfile_name'"==".dta" continue

			* Extract the first letter (e, r, s)
			if ustrregexm("`rfile_name'", "^_([ers])_")==1 local first_letter = ustrregexs(1) 
			if "`first_letter'"=="r" local treturn = "return"
			else                     local treturn = "`first_letter'return"

			* Extract the type (macros, matrix, scalars)
			if 	ustrregexm("`rfile_name'", "^[^_]*_[^_]*_([a-z]+)") local type = ustrregexs(1) 

			* Extract any extra details after matrix (if present)
			if ustrregexm("`rfile_name'", "_matrix_([A-Za-z0-9_]+)") local extra = ustrregexs(1) 
    
			if "`type'"=="scalars"|"`type'"=="macros" {
				cwf ``type'_results'
				clear
				//Import scalar or macro file
				use `dir'/`call_hash'`rfile_name', clear
				qui count
				if r(N)==0 continue 
				foreach num of numlist 1(1)`r(N)' {
					local item     = item[`num']
					local contents = contents[`num']
					// Return this element
					if "`type'"=="macros"  {
						if "`first_letter'"=="r" cap return local item = `contents'
						else cache_`treturn' "`contents'", name(`item') type("local")
					}
					else if "`type'"=="scalars" {
						if "`first_letter'"=="r" return scalar `item' = `contents'
						else cache_`treturn' `contents', name(`item') type("scalar")
					}
				}
			}
		}
		cwf	`origframe'			


		//========================================================
		// Print command output
		//========================================================
		if `logfound'==1 {
			dis "printing output"
			type "`log'"
		}	
		exit	
	}


	//========================================================
	// If cache is not found 
	//========================================================
	* Save baseline frames before running command
	qui frames dir
	local allframes = r(frames)
	local allframes : subinstr local allframes " " ",", all 

	//Log output and then this can be printed when cached command called
	tempname logfile
	qui log using "`dir'/`call_hash'", name(`logfile')

	* Now, run the command on the right
	`right'

	local dtasave   = 0
	//========================================================
	// Store results
	//========================================================

	// ret list --------------
	local classes = "r e s"
	local macro_namres = "scalars  macros  matrices  functions"
	// get all the names of macros with info and save results 
	foreach l of local classes {
		foreach n of local macro_namres {
			local `l'`n': `l'(`n')
			//disp "{res:`l'`n'}: ``l'`n''"
			if ("``l'`n''" != "") {
				local ret_names = "`ret_names' `l'`n'"
			}
		}
	}

	foreach n in scalars macros matrices {
		tempname `n'_results
		frame create ``n'_results'
	}

	// Save results in cache directory (type-specific)
	foreach element of local ret_names {
		// Get class (e, s or r)
		local class   = substr("`element'", 1, 1)
		local element = substr("`element'", 2, .)

		// Save matrices as dta file for each matrix
		if regexm("`element'", "matrices")==1 {
			// generate clean frame to use svmat for saving to _cache
			cwf `matrices_results'

			// Now, iterate through all matrices, saving data and exporting
			//   Potentially can set up a savematrix function and a loadmatrix function
			local matrices: `class'(`element')
			foreach mat of local matrices {
				//Name matrix as __ to avoid problems, eg trying to store column names like _cons
				mat __ = `class'(`mat')
				qui svmat __

				//Save matrix rownames as an extra variable
				local rnames: rownames __
				qui gen _rownames = ""
				local j=1
				foreach name of local rnames {
					qui replace _rownames = "`name'" in `j'
					local ++j
				}
				//Save matrix colnames as a variable label
				local cnames: colnames __
				local j=1
				foreach name of local cnames {
					lab var __`j' "`name'"
					local ++j
				}
				qui save "`dir'/`call_hash'_`class'_matrix_`mat'.dta"
				clear
			}
			cwf `origframe'
		}		
		// Now, deal with scalars and macros
		else if regexm("`element'", "scalar|macro")==1 {
			local names: `class'(`element')
			local n_items: word count `names'

			// change to clean frame to import contents of list
			cwf ``element'_results'
			qui set obs `n_items'

			qui gen item = ""
			if regexm("`element'", "scalar")==1 {
				qui gen contents = .
			}
			else {
				qui gen contents = ""
			}
			local j=1
			foreach name of local names {
				qui replace item = "`name'" in `j'
				qui replace contents = `class'(`name') in `j'
				local ++j
			}
			//Save all scalars or macros
			qui save "`dir'/`call_hash'_`class'_`element'.dta"
			clear
			cwf `origframe'
		}
		// Finally, deal with functions (esample probably saved as variable)
		//   From documentation (https://www.stata.com/manuals/rstoredresults.pdf):
		//   Functions are stored by e-class commands only, and the only function existing is e(sample)
		else if regexm("`element'", "functions")==1 {
			// Based on above comment, this must be e(sample)
			//   For now, let's save the whole dataset.  We can evaluate saving just the funcvar
			//   If saving just funcvar, will need to do a "merge 1:1 _n" later (not clear this is faster)
			qui gen _funcvar = e(sample)
			qui save "`dir'/`call_hash'.dta"
			drop _funcvar
			local dtasave = 1
		}
	}	
	return add // add results of cmd

	// clean up storage frames
	foreach n in scalars macros matrices {
		frame drop ``n'_results'
	}
	qui log close `logfile'

	// data in memory ----------
	qui datasignature 
	local datasignature2 = "`r(datasignature)'"
	if ("`datasignature'" != "`datasignature2'") & `dtasave'==0 {
		dis "Data has changed, saving data"
		qui save "`dir'/`call_hash'.dta"
	}
	else {
		dis "Data has not changed or already saved"
	}

	// data frame ----------
	// if the the cmd returns a data frame, save it
	// NOTE: a simple version of this just generates the list of new frames and
	//   saves them all at once using frames save.  However, there is a risk that
	//   a command alters a specific frame, so it is not enough to just check for
	//   new frames.  We need to loop through all frames doing a datasignature
	//   and then re-check the datasignature, saving if it has changed.
	qui frames dir
	local finalframes = r(frames)
	//foreach f of local finalframes {
	//}

	//========================================================
	// 
	//========================================================





end

//========================================================
// Aux programs
//========================================================


// set directory
cap program drop cache_setdir
program define cache_setdir, rclass
	mata {
			cachedir = pwd() + "_cache"
			if (!direxists(cachedir)) {
				mkdir(cachedir)
			}
			st_local("dir", cachedir)
		}
	
	return local dir = "`dir'"
end


// ereturn program
cap program drop cache_ereturn
program define cache_ereturn, eclass
	syntax anything(name=element), name(string) type(string)
	ereturn `type' `name' = `element'
end

// sreturn program
cap program drop cache_sreturn
program define cache_sreturn, sclass
	syntax anything(name=element), name(string) type(string)
	sreturn `type' `name'=`element'
end

// return program (could be removed if desired as cache is r-class)
cap program drop cache_return
program define cache_return, rclass
	syntax anything(name=element), name(string) type(string)
	return `type' `name'=`element'
end


exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1a. What shall we do with n-class commands that don't alter previous return lists (eg dis "Hello world!")
1b. In general, this is a point for xreturn with previous yreturns issued where x neq y.  A solution is to clear return, ereturn and sreturn prior to running...
2. Need to build in frame caching (ideas, or just looped data signature)
3. Need to build in extended functions such as clean
4. Need to refactorize heavily


Version Control:




*##s
	// mata {
	// 	cachedir = pwd() + "_cache"
	// 	if (!direxists(cachedir)) {
	// 		mkdir(cachedir)
	// 	}
	// 	st_local("dir", cachedir)
	// }
	*##e