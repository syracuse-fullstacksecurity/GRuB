/*
Copyright (c) <2020> <Kai Li, Yuzhe Tang, Zhehu Yuan>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

contract Secure_DB{
    
    bytes32 root=0xcf55e1dcf75e73ec3efb8c0535b465af6b154ff8ce9fd26de2c8c872b3e98909;
    mapping(uint256 => bytes32) btcblocks;
    mapping(uint256=>int8) Valid;    // 1 -> invalid, 2-> valid, using integer to save cost
    
    // onchain query
    function read(uint256[] memory indices) public payable {
      bytes32 ret;
      for (uint i=0; i<indices.length; ++i)
        ret = btcblocks[indices[i]];
    }

    // off-chain point query
    function read(uint256 index, bytes32[] memory values, bool R, uint256[] memory indices, bytes32[] memory proof, uint8 depth) public payable {
	    bytes32 ret;
	    // authenticate the proof
	    if (indices.length > 0){
		    verify(root, depth, indices, values, proof);
	    }

	    if (values.length>=1){
		    if (R){
			    btcblocks[index] = values[0];
 			    // no need to maintain the flag
			    /*if (Valid[index] != 2)
				    Valid[index] = 2;
			    */
		    }
	    }
	    else{
		    // record onchain
		    ret = btcblocks[index];
	    }
    }
    
    // off-chain point query
    function read(uint256[] memory keys, bytes32[] memory values, uint16 replicateCount, uint256[] memory indices, bytes32[] memory proof, uint8 depth) public payable {

        bytes32 ret;
        // authenticate the proof
        if (indices.length > 0){
            verify(root, depth, indices, values, proof);
        }

        for (uint256 i=0; i<keys.length; ++i){
            // off-chain read
            if (i<values.length){
                // replicate
                if (replicateCount > i){
                    btcblocks[keys[i]] = values[i];
                }
            }
            else
            {
                ret = btcblocks[keys[i]];
            }
        }
    }
    
    // off-chain point write
    function write(bytes32 digest) public {
        root = digest;
    }
    
    // initialize the storage
    function load(uint256[] memory indices) public {
        for (uint256 i=0; i<indices.length; ++i){
            Valid[indices[i]] = 1;
            btcblocks[indices[i]] = 0xcf55e1dcf75e73ec3efb8c0535b465af6b154ff8ce9fd26de2c8c872b3e98909;
        }
    }
    
    // if no on-chain record needs to be invalidated
    function update_digest(bytes32 digest) public {
        root = digest;
    }

    //// reference to https://gist.github.com/Recmo/0dbbaa26c051bea517cd3a8f1de3560a
    function hash_leaf(bytes32 value)
        internal pure
        returns (bytes32 hash)
    {
        return keccak256(abi.encodePacked(value));
    }

    function hash_node(bytes32 left, bytes32 right)
        internal
        returns (bytes32 hash)
    {
        assembly {
            mstore(0x00, left)
            mstore(0x20, right)
            hash := keccak256(0x00, 0x40)
        }
        return hash;
    }
    
    function verify(bytes32 root, uint8 depth, uint256[] memory indices, bytes32[] memory values,
        bytes32[] memory proof
    ) 
    internal returns(bool) 
    {
        bytes32 computedHash = hash_leaf(values[0]);
        for (uint16 i=1; i<values.length; ++i){
	    uint256 index = indices[i];
            computedHash=hash_node(computedHash, hash_leaf(values[i]));
        }
        
        for (uint16 j=0; j<proof.length; ++j){
            computedHash = hash_node(computedHash, proof[j]);
        }
        return root == computedHash;
    }
}
