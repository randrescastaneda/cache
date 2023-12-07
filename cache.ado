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

if "`1'" == "" {
	di _n as txt "  Syntax: " in wh "witch" in gr" filename [ " _c
	di in wh ", noa" in gr "ll " in wh "noallt" in gr "ypes ]"
	exit
}




//========================================================
//  SPLIT
//========================================================


* Split the overall command, stored in `0' in a left and right part.
local 0 "cache subcmd, option1() option2() opt : pip wb, clear"

gettoken left right : 0, parse(":")

// remove first : in each part (left part should not have any)
local left:  subinstr local left ":" ""
local right: subinstr local right ":" ""

//========================================================
// Syntax of left part
//========================================================
* Regular syntax parsing for cache
local 0 : copy local left
syntax [anything(name=subcmd)]   ///
[,                   	   /// 
dir                      ///
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

* dir
if ("`dir'" == "") {
	*##s
	mata {
		cachedir = pwd() + "_cache"
		if (!direxists(cachedir)) {
			mkdir(cachedir)
		}
		st_local("dir", cachedir)
	}
	*##e
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
exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:


