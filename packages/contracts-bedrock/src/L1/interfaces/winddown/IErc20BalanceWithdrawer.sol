// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IBalanceWithdrawer } from "src/L1/interfaces/winddown/IBalanceWithdrawer.sol";

/// @title IErc20BalanceWithdrawer
/// @notice Interface for the Erc20BalanceWithdrawer contract
interface IErc20BalanceWithdrawer is IBalanceWithdrawer {
    function withdrawErc20Balance(
        address _user,
        uint256 _daiBalance,
        uint256 _usdcBalance,
        uint256 _usdtBalance,
        uint256 _gtcBalance
    )
        external;
}
