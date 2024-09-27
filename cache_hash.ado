/*==================================================
project:       Get the hash of the cmd line
Author:        R.Andres Castaneda 
E-email:       acastanedaa@worldbank.org
url:           
Dependencies:  The World Bank
----------------------------------------------------
Creation Date:     4 May 2023 - 11:36:23
Modification Date:   
Do-file version:    01
References:          
Output:             
==================================================*/

/*==================================================
              0: Program set up
==================================================*/
program define cache_hash, rclass
syntax [anything(name=subcmd)]   ///
[,                   	   /// 
	pause                    ///
	clear                    ///
	replace                  ///
	force                    ///
    *                        ///
] 
version 16.1


/*==================================================
    1: get command call hash
==================================================*/
if ("`subcmd'" == "get")  {
    cache_hash_get, `options'
    return add
}



/*==================================================
              2: 
==================================================*/


end

//------------ Get Hash based on string 
program define cache_hash_get, rclass
	syntax [anything(name=subcmd)], [   ///
	cmd_call(string)               ///
	PREfix(string)              ///
	]
	
	
	qui {
		if ("`prefix'" == "") local prefix = "ch"
		tempname shash
		
		mata:  st_numscalar("`shash'", hash1(`"`prefix'`cmd_call'"', ., 2)) 
		local hash = "_ch" + strofreal(`shash', "%12.0g")
		return local chhash = "`chhash'"
	}

exit
/* End of do-file */

><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><

Notes:
1.
2.
3.


Version Control:


