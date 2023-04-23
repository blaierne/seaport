certoraRun.exe `
    ./certora/harness/KotlinTest.sol:KotlinTest `
--verify KotlinTest:./certora/specs/KotlinTest.spec `
--solc solc8.13 `
--loop_iter 3 `
--staging master `
--msg "KotlinTest"
