methods{
	function name() external returns (bytes32) envfree;
}

rule OpenSeaName
{
	bytes32 nameBytes;
	nameBytes = name();
	assert(nameBytes == 0x07536561706f7274);
}