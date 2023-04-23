certoraRun.exe `
    ./certora/harness/SignedZoneMunged.sol:SignedZoneMunged `
--verify SignedZoneMunged:./certora/specs/sanity.spec `
--solc solc8.13 `
--loop_iter 3 `
--staging pre_cvl2 `
--optimistic_hashing `
--msg "SIP7 sanity"
