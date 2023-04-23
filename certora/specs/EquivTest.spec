methods{
	function deriveEIP712Digest_Sol(bytes32,bytes32) external returns(bytes32) envfree;
	function deriveEIP712Digest_Asm(bytes32,bytes32) external returns(bytes32) envfree;
}

rule deriveEIP712Digest_EquiRevert(bytes32 domainSeparator, bytes32 signedOrderHash)
{
	bool Asm_reverted;
	bool Sol_reverted;
	deriveEIP712Digest_Asm@withrevert(domainSeparator,signedOrderHash);
	Asm_reverted = lastReverted;
	deriveEIP712Digest_Sol@withrevert(domainSeparator,signedOrderHash);
	Sol_reverted = lastReverted;
	assert(Asm_reverted == Sol_reverted);
}

rule deriveEIP712Digest_EquiValue(bytes32 domainSeparator, bytes32 signedOrderHash)
{
	bytes32 digestAsm;
	bytes32 digestSol;
	digestAsm = deriveEIP712Digest_Asm(domainSeparator,signedOrderHash);
	digestSol = deriveEIP712Digest_Sol(domainSeparator,signedOrderHash);
	assert(digestAsm == digestSol);
}