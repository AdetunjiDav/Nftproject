// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/NFTProject.sol";

contract NFTProjectTest is Test {
    NFTProject public nftContract;
    address public owner;
    address public user1;
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        
        // Deploy the contract
        nftContract = new NFTProject();
    }
    
    function testMint() public {
        // Test minting functionality
        vm.prank(user1);
        // Add your mint logic here based on your contract
        // Example: nftContract.mint();
        
        assertTrue(true); // Replace with actual assertions
    }
    
    function testOwner() public {
        // Test that owner is set correctly
        assertEq(nftContract.owner(), owner);
    }
}
