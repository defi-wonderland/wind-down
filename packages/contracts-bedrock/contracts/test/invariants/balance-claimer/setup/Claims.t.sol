// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IErc20BalanceWithdrawer} from "contracts/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import {Tokens} from "./Tokens.t.sol";

contract Claims is Tokens {
    struct Claim {
        address user;
        uint256 ethAmount;
        address[] tokens;
        uint256[] tokenAmounts;
    }

    bytes32[] internal tree;
    Claim[] internal ghost_validClaims;
    mapping(bytes32 => bool) internal ghost_claimed;
    mapping(bytes32 => bool) internal ghost_claimInTree;

    constructor() {
        address user = 0x0000000000000000000000000000000000010000;
        address[] memory tokens = new address[](1);
        tokens[0] = address(supportedTokens[0]);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        Claim memory claim = Claim({user: user, ethAmount: 1 ether, tokens: tokens, tokenAmounts: amounts});
        ghost_validClaims.push(claim);
        ghost_claimInTree[_hashClaim(claim)] = true;
        tree.push(_hashClaim(claim));
    }

    function _hashClaim(Claim memory claim) internal pure returns (bytes32) {
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory erc20Claims =
            new IErc20BalanceWithdrawer.Erc20BalanceClaim[](claim.tokens.length);
        for (uint256 i = 0; i < claim.tokens.length; i++) {
            erc20Claims[i].token = claim.tokens[i];
            erc20Claims[i].balance = claim.tokenAmounts[i];
        }
        return keccak256(bytes.concat(keccak256(abi.encode(claim.user, claim.ethAmount, erc20Claims))));
    }

    function _hashClaim(address user, uint256 ethAmount, IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory erc20Claims)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(bytes.concat(keccak256(abi.encode(user, ethAmount, erc20Claims))));
    }

    function _claimToErc20ClaimArray(Claim memory claim)
        internal
        pure
        returns (IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory)
    {
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory erc20Claims =
            new IErc20BalanceWithdrawer.Erc20BalanceClaim[](claim.tokens.length);
        for (uint256 i = 0; i < claim.tokens.length; i++) {
            erc20Claims[i].token = claim.tokens[i];
            erc20Claims[i].balance = claim.tokenAmounts[i];
        }
        return erc20Claims;
    }
}
