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

	if ("`files'" != "") {
		// use files
		exit
	}

	//========================================================
	// If cache is not found 
	//========================================================
	* Now, run the command on the right
	`right'
	
	//========================================================
	// Store results
	//========================================================

	// ret list --------------
	local classes = "r e s"
	local macro_namres = "scalars  macros  matrices  functions"
	// get all the nammes of macros with info and save results 
	foreach l of local classes {
		foreach n of local macro_namres {
			local `l'`n': `l'(`n')
			//disp "{res:`l'`n'}: ``l'`n''"
			if ("``l'`n''" != "") {
				local ret_names = "`ret_names' `l'`n'"
			}
		}
	}
	return add // add results of cmd

	// Now we have to save results in frame or dta or something.
	

	// data frame ----------
	// if the the cmd returns a data frame, save it




	//========================================================
	// 
	//========================================================


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