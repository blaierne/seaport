methods{
	function name_unaligned() external returns (bytes32) envfree;
	function name_aligned() external returns (bytes32) envfree;
}

rule OpenSeaName_UnAligned
{
	bytes32 nameBytes;
	nameBytes = name_unaligned();
	assert(nameBytes == 0x536561706f7274);
}

rule OpenSeaName_Aligned
{
	bytes32 nameBytes;
	nameBytes = name_aligned();
	assert(nameBytes == 0x536561706f7274);
}