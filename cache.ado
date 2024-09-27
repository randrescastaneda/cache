/*==================================================
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
program define cache, rclass
version 16.0

//========================================================
//  SPLIT
//========================================================


* Split the overall command, stored in `0' in a left and right part.
local 0 "cache subcmd, option1() option2() opt : pip wb, clear"

gettoken left right : 0, parse(":")

// remove first : in each part (left part should not have any)
local left:  subinstr local left ":" ""
local right: subinstr local right ":" ""

if ("`left'" == "")  {
	dis "{err: make sure you follow this syntax}:"
	dis _n "{cmd: cache {it:[subcmd] [, options]}: command}"
	error 197
}


//========================================================
// Syntax of left part
//========================================================
* Regular syntax parsing for cache
local 0 : copy local left
syntax [anything(name=subcmd)]   ///
[,                   	   /// 
	dir(string)              ///
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



//========================================================
// Execution of right part
//========================================================
* Now, run the command on the right
`right'

* Run any code you want to run after the command on the right









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