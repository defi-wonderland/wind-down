// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {IErc20BalanceWithdrawer} from "contracts/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import {MerkleTreeGenerator} from "contracts/test/libraries/MerkleTreeGenerator.t.sol";
import {Tokens} from "./Tokens.t.sol";
import {ClaimsList} from "./ClaimList.t.sol";

contract Claims is Tokens, ClaimsList, MerkleTreeGenerator {
    struct Claim {
        address user;
        uint256 ethAmount;
        address[] tokens;
        uint256[] tokenAmounts;
    }

    bytes32[] internal tree;
    bytes32[] internal leaves;
    Claim[] internal ghost_validClaims;
    mapping(address => bool) internal ghost_claimed;
    mapping(bytes32 => bool) internal ghost_claimInTree;
    // only used as dynamic array
    address[] private _tokens;
    // only used as dynamic array
    uint256[] private _amounts;

    constructor() {
        for (uint256 i = 0; i < randomClaims.length; i++) {
            ClaimEntry memory rawClaim = randomClaims[i];
            if (rawClaim.daiAmount > 0) {
                _tokens.push(address(supportedTokens[0]));
                _amounts.push(rawClaim.daiAmount);
            }
            if (rawClaim.gtcAmount > 0) {
                _tokens.push(address(supportedTokens[1]));
                _amounts.push(rawClaim.gtcAmount);
            }
            if (rawClaim.usdtAmount > 0) {
                _tokens.push(address(supportedTokens[2]));
                _amounts.push(rawClaim.usdtAmount);
            }
            if (rawClaim.usdcAmount > 0) {
                _tokens.push(address(supportedTokens[3]));
                _amounts.push(rawClaim.usdcAmount);
            }
            Claim memory claim = Claim({
                user: rawClaim.recipient,
                ethAmount: rawClaim.ethAmount,
                tokens: _tokens,
                tokenAmounts: _amounts
            });
            delete _amounts;
            delete _tokens;
            ghost_validClaims.push(claim);
            leaves.push(_hashClaim(claim));
        }
        tree = generateMerkleTree(leaves);
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
