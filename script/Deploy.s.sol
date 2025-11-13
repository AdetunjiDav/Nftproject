// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract Deploy is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(pk);

        vm.startBroadcast(pk);

        MyNFT nft = new MyNFT(owner);

        // Example IPFS URI (replace with your own after upload)
        string memory uri = "ipfs://bafybeieknwo5nsiggwtb7igxsapwucda3bgmua4lxcv5zqtcvz52r7hmvi/0.json";
        nft.safeMint(owner, uri);

        emit log_address(address(nft));
        vm.stopBroadcast();
    }
}
