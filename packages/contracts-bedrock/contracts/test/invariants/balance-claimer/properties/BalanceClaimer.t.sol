// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import {BalanceClaimerSetup} from '../setup/BalanceClaimer.t.sol';

contract BalanceClaimerProperties is BalanceClaimerSetup {
  /// @custom:property-id 1
  /// @custom:property foo
  function property_foo() external view {
  }
}
