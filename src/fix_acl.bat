@echo off
icacls "D:\hake\lotus\dumps\umbrella_live.dmp" /grant "%USERNAME%":(R) >> D:\hake\lotus\dumps\acl_result.txt 2>&1
icacls "D:\hake\lotus\dumps\umbrella_live.dmp" /grant *S-1-5-32-545:(R) >> D:\hake\lotus\dumps\acl_result.txt 2>&1
echo DONE >> D:\hake\lotus\dumps\acl_result.txt
