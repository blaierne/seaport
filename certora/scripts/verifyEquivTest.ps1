certoraRun.exe `
    ./certora/harness/EquivTest.sol:EquivTest `
--verify EquivTest:./certora/specs/EquivTest.spec `
--solc solc8.13 `
--loop_iter 3 `
--cloud pre_cvl2 `
--optimistic_hashing `
--msg "SIP7 EquivTest"
