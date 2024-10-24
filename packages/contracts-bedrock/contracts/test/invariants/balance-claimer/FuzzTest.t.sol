// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/console.sol";

import {BalanceClaimerGuidedHandlers} from "./handlers/guided/BalanceClaimer.t.sol";
import {BalanceClaimerUnguidedHandlers} from "./handlers/unguided/BalanceClaimer.t.sol";
import {BalanceClaimerProperties} from "./properties/BalanceClaimer.t.sol";
import {IErc20BalanceWithdrawer} from "contracts/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";

contract FuzzTest is BalanceClaimerGuidedHandlers, BalanceClaimerUnguidedHandlers, BalanceClaimerProperties {}
