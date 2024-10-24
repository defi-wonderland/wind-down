// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {BalanceClaimerGuidedHandlers} from './handlers/guided/BalanceClaimer.t.sol';
import {BalanceClaimerUnguidedHandlers} from './handlers/unguided/BalanceClaimer.t.sol';
import {BalanceClaimerProperties} from './properties/BalanceClaimer.t.sol';

contract FuzzTest is BalanceClaimerGuidedHandlers, BalanceClaimerUnguidedHandlers, BalanceClaimerProperties {}
