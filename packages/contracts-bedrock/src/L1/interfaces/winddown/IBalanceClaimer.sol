// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title IBalanceClaimer
/// @notice Interface for the BalanceClaimer contract
interface IBalanceClaimer {
    /// @notice Emitted when a user claims their balance
    event BalanceClaimed(
        address indexed user,
        uint256 daiBalance,
        uint256 usdcBalance,
        uint256 usdtBalance,
        uint256 gtcBalance,
        uint256 ethBalance
    );

    /// @notice Thrown when the user has no balance to claim
    error NoBalanceToClaim();

    function claim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _daiBalance,
        uint256 _usdcBalance,
        uint256 _usdtBalance,
        uint256 _gtcBalance,
        uint256 _ethBalance
    )
        external;

    function canClaim(
        bytes32[] calldata _proof,
        address _user,
        uint256 _daiBalance,
        uint256 _usdcBalance,
        uint256 _usdtBalance,
        uint256 _gtcBalance,
        uint256 _ethBalance
    )
        external
        view
        returns (bool _canClaimTokens);

    function root() external view returns (bytes32 _root);

    function claimed(address _user) external view returns (bool _claimed);
}
