# Performance `OPTIMIZED REWIND` vs `ONE BY ONE REVERT`
To make a comparison tests test.funcional.fork_extension.performance_.* vs test.funcional.sql_fork_extension.performance_.*

## Results
| Test                        | OPTIMIZED REWIND [ms]        | ONE BY ONE REVERT [ms]          | OnybyOne/Optimized [-] |
| :------------------------   | :-----------------------     | :---------------------------    | :-------------------   |
| Insert 10k rows in one query| 55, 55, 55 **[55]**          | 36, 37, 37  **[36.6]**          |   0.67                 |
| Insert 10k rows one by one  | 285, 277, 282 **[281.3]**    | 245, 244, 258 **[249]**         |   0.89                 |
| Delete 10k rows in one query| 20, 20, 22 **[20.6]**        | 16, 16, 16 **[16] **            |   0.78                 |
| Delete 10k rows one by one  | 3670, 3635, 3688 **[3664.3]**| 3576, 3611, 3584 **[3590]**     |   0.97                 |
| Update 10k rows in one query| 56, 56, 57 **[57.6]**        | 37, 37, 37 **[37]**             |   0.64                 |
| Update 10k rows one by one  | 6368, 6478, 6494 **[6446.6]**| 6500, 6448, 6512 **[6486]**     |   1                    |
| Truncate 10k rows           | 31, 31, 31 **[31]**          | 12, 12, 12 **[12]**             |   0.39                 |
| Back from insert 10k rows   | 23, 24, 23 **[23.3]**        | 3188, 3173, 3152 **[3171]**     |   135                  |
| Back from delete 10k rows   | 36, 35, 36 **[35.6]**        | 8010, 8314, 8052 **[8152]**     |   228                  |
| Back from update 10k rows   | 48, 48, 48 **[48]**          | 13497, 13513, 13363 **[13457]** |   280                  |
| Back from truncate 10k rows | 32, 31, 32 **[35.6]**        | 8026, 8004, 8117 **[8049]**     |   226                  |


