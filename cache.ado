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


	//========================================================
	// Syntax of left part
	//========================================================
	* Regular syntax parsing for cache
	local 0 : copy local left
	syntax [anything(name=subcmd)]   ///
	[,                   	   /// 
		dir(string)              ///
		project(string)          ///
		prefix(string)           ///
		noDATA                   ///
		pause                    ///
		clear                    ///
		replace                  ///
		force                    ///
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

	// Find files --------------------------
	local files: dir "`dir'" files "`call_hash'*.dta"
	if length(`"`files'"') != 0 {
		dis "Cache found"
		// use files
		exit
	}

	//========================================================
	// Print output if necessary 
	//========================================================
	// Need to figure out ereturn post and pass back e(sample)  
	// ereturn post b V, esample(funcvar)


	//========================================================
	// If cache is not found 
	//========================================================
	* Save baseline frames before running command
	qui frames dir
	local allframes = r(frames)
	local allframes : subinstr local allframes " " ",", all 

	* Now, run the command on the right
	`right'

	local origframe = c(frame)
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
	//dis "`ret_names'"
	return add // add results of cmd

	// Save results in cache directory (type-specific)
	foreach element of local ret_names {
		// Get class (e, s or r)
		local class   = substr("`element'", 1, 1)
		local element = substr("`element'", 2, .)

		// Save matrices as dta file for each matrix
		cap frame drop matrix_results
		if regexm("`element'", "matrices")==1 {
			// generate clean frame to use svmat for saving to _cache
			cap frame create matrix_results
			cwf matrix_results

			// Now, iterate through all matrices, saving data and exporting
			//   In below, still need to generate column for rownames
			//   Potentially can set up a savematrix function and a loadmatrix function
			local matrices: `class'(`element')
			foreach mat of local matrices {
				//Name matrix as __ to avoid problems, eg trying to store column names like _cons
				mat __ = `class'(`mat')
				qui svmat __, names(matcol)
				qui save "`dir'/`call_hash'_matrix_`class'_`mat'.dta"
				clear
			}
			cwf `origframe'
			frame drop matrix_results
		}		
		// Now, deal with scalars and macros
		else if regexm("`element'", "scalar|macro")==1 {
			local names: `class'(`element')
			local n_items: word count `names'

			// generate clean frame to import contents of list
			cap frame create `element'_results
			cwf `element'_results
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
			frame drop `element'_results
		}
		// Finally, deal with functions (esample probably saved as variable)
		//   From documentation (https://www.stata.com/manuals/rstoredresults.pdf):
		//   Functions are stored by e-class commands only, and the only function existing is e(sample)
		else if regexm("`element'", "functions")==1 {
			// Based on above comment, this must be e(sample)
			//   For now, let's save the whole dataset.  We can evaluate saving just the funcvar
			//   If saving just funcvar, will need to do a "merge 1:1 _n" later (not clear this is faster)
			tempvar funcvar 
			qui gen `funcvar' = e(sample)
			qui save "`dir'/`call_hash'.dta"
			drop `funcvar'
			local dtasave = 1
		}
	}	

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
	//   new frames.  We probably need to loop through all frames doing a datasignature
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




exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


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