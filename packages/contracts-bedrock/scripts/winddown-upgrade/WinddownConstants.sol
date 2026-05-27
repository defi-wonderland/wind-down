// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

library WinddownConstants {
    address constant L1_STANDARD_BRIDGE_PROXY = 0xD0204B9527C1bA7bD765Fa5CCD9355d38338272b;
    address constant OPTIMISM_PORTAL_PROXY = 0xb26Fd985c5959bBB382BAFdD0b879E149e48116c;

    // OptimismPortal constructor parameters
    address constant L2_ORACLE = 0xA38d0c4E6319F9045F20318BA5f04CDe94208608;
    address constant GUARDIAN = 0x39E13D1AB040F6EA58CE19998edCe01B3C365f84;
    address constant SYSTEM_CONFIG = 0x7Df716EAD1d83a2BF35B416B7BC84bd0700357C9;

    // L1StandardBridge constructor parameters
    address constant MESSENGER = 0x97BAf688E5d0465E149d1d5B497Ca99392a6760e;

    // Prod generated merkle root
    bytes32 constant MERKLE_ROOT = 0xdc8d72680e7aa76a53e17f537ee4455c1546c32badeac410313687a14bbe9625;

    // Clawback upgrade
    /// @dev Address of the BalanceClaimer Proxy deployed by Winddown-implementation.s.sol.
    address constant BALANCE_CLAIMER_PROXY = 0x0Ca4C7A370E0155c77a33e78443a54D749E0BC21;

    /// @dev Non-zero garbage Merkle root passed to the v2 BalanceClaimer impl so any
    ///      `claim` call reverts; funds move only via {BalanceClaimer.clawback}.
    bytes32 constant CLAWBACK_GARBAGE_ROOT = keccak256("WINDDOWN_CLAWBACK_DISABLED_ROOT");

    /// @dev Mirrors `BalanceClaimer.FOUNDATION`. Used by deploy / upgrade scripts
    ///      to reject impls whose bytecode bakes in a different receiver. Keep in
    ///      sync with `contracts/L1/winddown/BalanceClaimer.sol`.
    address constant FOUNDATION = 0x50ccf30828DdDA5aDFd25A3CEc24b83F13496774;
}
