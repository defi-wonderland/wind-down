// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract FuzzERC20 is MockERC20 {
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}

contract Tokens {
    uint8 internal constant TOKENS = 4;
    uint256 internal constant INITIAL_BALANCE = 100000e18;
    IERC20[] internal supportedTokens;

    mapping(address => uint256) internal ghost_claimedTokens;
    uint256 internal ghost_claimedEther;

    constructor() {
        for (uint256 i = 0; i < TOKENS; i++) {
            // TODO: use bytecode from production tokens
            FuzzERC20 token = new FuzzERC20();
            // TODO: use 6 decimals for usdt
            token.initialize("name", "symbol", 18);
            supportedTokens.push(token);
        }
    }
}
