// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// Testing
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { Bridge_Initializer } from "test/setup/Bridge_Initializer.sol";
import { MerkleTreeGenerator } from "test/libraries/MerkleTreeGenerator.t.sol";

// Contracts
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { BalanceClaimer } from "src/L1/winddown/BalanceClaimer.sol";

// Interfaces
import { IBalanceClaimer } from "src/L1/interfaces/winddown/IBalanceClaimer.sol";
import { IBalanceWithdrawer } from "src/L1/interfaces/winddown/IBalanceWithdrawer.sol";
import { IErc20BalanceWithdrawer } from "src/L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IEthBalanceWithdrawer } from "src/L1/interfaces/winddown/IEthBalanceWithdrawer.sol";

contract BalanceClaimer_Initialize_Test is Bridge_Initializer {
    /// @dev Test that the constructor sets the correct values.
    /// @notice Marked virtual to be overridden in
    ///         test/kontrol/deployment/DeploymentSummary.t.sol
    function test_constructor_succeeds() external virtual {
        IBalanceClaimer impl = IBalanceClaimer(deploy.mustGetAddress("BalanceClaimer"));
        assertEq(impl.root(), bytes32(0));
        assertEq(address(impl.ethBalanceWithdrawer()), address(0));
        assertEq(address(impl.erc20BalanceWithdrawer()), address(0));
    }

    /// @dev Test that the initialize function sets the correct values.
    function test_initialize_succeeds() external view {
        // TODO: using test root, change to real root
        assertEq(balanceClaimer.root(), bytes32(0));
        assertEq(address(balanceClaimer.ethBalanceWithdrawer()), address(optimismPortal));
        assertEq(address(balanceClaimer.erc20BalanceWithdrawer()), address(l1StandardBridge));
    }
}

contract BalanceClaimer_Test is Bridge_Initializer {
    using stdStorage for StdStorage;

    struct ClaimData {
        uint256 ethBalance;
        uint256 balanceToken1;
        uint256 balanceToken2;
        uint256 balanceToken3;
    }

    MerkleTreeGenerator merkleTreeGenerator;

    address _alice = makeAddr("alice");
    address _bob = makeAddr("bob");
    address _charlie = makeAddr("charlie");

    address _token1 = makeAddr("token1");
    address _token2 = makeAddr("token2");
    address _token3 = makeAddr("token3");

    address[] _users;

    function setUp() public override {
        super.setUp();
        merkleTreeGenerator = new MerkleTreeGenerator();
        _users = new address[](3);
        _users[0] = _alice;
        _users[1] = _bob;
        _users[2] = _charlie;
    }

    /// @dev Get the erc20 token balances for the user
    function _getErc20TokenBalances(
        uint256 _balanceToken1,
        uint256 _balanceToken2,
        uint256 _balanceToken3
    )
        internal
        view
        returns (IBalanceWithdrawer.Erc20BalanceClaim[] memory _erc20TokenBalances)
    {
        uint8 _length;
        IBalanceWithdrawer.Erc20BalanceClaim[] memory _auxErc20TokenBalances =
            new IBalanceWithdrawer.Erc20BalanceClaim[](3);

        if (_balanceToken1 > 0) {
            _length++;
            _auxErc20TokenBalances[0] =
                IBalanceWithdrawer.Erc20BalanceClaim({ token: _token1, balance: _balanceToken1 });
        }
        if (_balanceToken2 > 0) {
            _length++;
            _auxErc20TokenBalances[1] =
                IBalanceWithdrawer.Erc20BalanceClaim({ token: _token2, balance: _balanceToken2 });
        }
        if (_balanceToken3 > 0) {
            _length++;
            _auxErc20TokenBalances[2] =
                IBalanceWithdrawer.Erc20BalanceClaim({ token: _token3, balance: _balanceToken3 });
        }

        _erc20TokenBalances = new IBalanceWithdrawer.Erc20BalanceClaim[](_length);
        uint256 _index;
        for (uint256 _i = 0; _i < _auxErc20TokenBalances.length; _i++) {
            if (_auxErc20TokenBalances[_i].balance > 0) {
                _erc20TokenBalances[_index] = _auxErc20TokenBalances[_i];
                _index++;
            }
        }
    }

    /// @dev Get the leaves for the merkle tree
    function _getLeaves(ClaimData[3] memory _claimData) internal view returns (bytes32[] memory _leaves) {
        _leaves = new bytes32[](_claimData.length);
        for (uint256 _i; _i < _claimData.length; _i++) {
            IBalanceWithdrawer.Erc20BalanceClaim[] memory _erc20TokenBalances = _getErc20TokenBalances(
                _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
            );
            _leaves[_i] = keccak256(
                bytes.concat(keccak256(abi.encode(_users[_i], _claimData[_i].ethBalance, _erc20TokenBalances)))
            );
        }
    }

    /// @dev Generates the merkle tree, mock the root and set it in the storage
    function _mockRoot(bytes32[] memory _leaves) internal returns (bytes32[] memory _tree) {
        _tree = merkleTreeGenerator.generateMerkleTree(_leaves);
        bytes32 _root = _tree[0];
        stdstore.target(address(balanceClaimer)).sig(IBalanceClaimer.root.selector).checked_write(_root);
    }

    /// @dev Mock the erc20 balance withdraw call and set the expect call if at least one balance is greater than 0
    function _mockErc20BalanceWithdrawCallAndSetExpectCall(
        address _user,
        IBalanceWithdrawer.Erc20BalanceClaim[] memory _erc20TokenBalances
    )
        internal
    {
        bool _called;
        for (uint256 _i = 0; _i < _erc20TokenBalances.length; _i++) {
            if (_erc20TokenBalances[_i].balance > 0) {
                _called = true;
                break;
            }
        }
        if (!_called) {
            return;
        }
        vm.mockCall(
            address(balanceClaimer.erc20BalanceWithdrawer()),
            abi.encodeWithSelector(IErc20BalanceWithdrawer.withdrawErc20Balance.selector, _user, _erc20TokenBalances),
            abi.encode(true)
        );

        vm.expectCall(
            address(balanceClaimer.erc20BalanceWithdrawer()),
            abi.encodeWithSelector(IErc20BalanceWithdrawer.withdrawErc20Balance.selector, _user, _erc20TokenBalances)
        );
    }

    /// @dev Mock the eth balance withdraw call and set the expect call if the balance is greater than 0
    function _mockEthBalanceWithdrawCallAndSetExpectCall(address _user, uint256 _ethBalance) internal {
        if (_ethBalance == 0) {
            return;
        }
        vm.mockCall(
            address(balanceClaimer.ethBalanceWithdrawer()),
            abi.encodeWithSelector(IEthBalanceWithdrawer.withdrawEthBalance.selector, _user, _ethBalance),
            abi.encode(true)
        );

        vm.expectCall(
            address(balanceClaimer.ethBalanceWithdrawer()),
            abi.encodeWithSelector(IEthBalanceWithdrawer.withdrawEthBalance.selector, _user, _ethBalance)
        );
    }
}

contract BalanceClaimer_CanClaim_Test is BalanceClaimer_Test {
    /// @dev Test that the canClaim function returns true when the user is a legit claimer.
    function testFuzz_canClaim_returnsTrue(ClaimData[3] memory _claimData) external {
        bytes32[] memory _leaves = _getLeaves(_claimData);

        bytes32[] memory _tree = _mockRoot(_leaves);

        for (uint256 _i = 0; _i < _claimData.length; _i++) {
            bool _canClaim = balanceClaimer.canClaim(
                merkleTreeGenerator.getProof(_tree, merkleTreeGenerator.getIndex(_tree, _leaves[_i])),
                _users[_i],
                _claimData[_i].ethBalance,
                _getErc20TokenBalances(
                    _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
                )
            );
            assertTrue(_canClaim);
        }
    }

    /// @dev Test that the canClaim function returns false when the user is not a legit claimer.
    function testFuzz_canClaim_returnsFalse(ClaimData[3] memory _claimData) external {
        bytes32[] memory _leaves = _getLeaves(_claimData);

        bytes32[] memory _tree = _mockRoot(_leaves);

        for (uint256 _i = 0; _i < _claimData.length; _i++) {
            bool _canClaim = balanceClaimer.canClaim(
                merkleTreeGenerator.getProof(_tree, merkleTreeGenerator.getIndex(_tree, _leaves[_i])),
                makeAddr("random"),
                _claimData[_i].ethBalance,
                _getErc20TokenBalances(
                    _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
                )
            );
            assertFalse(_canClaim);
        }
    }
}

contract BalanceClaimer_Claim_Test is BalanceClaimer_Test {
    /// @dev Test that the canClaim function returns true when the user is a legit claimer.
    function testFuzz_Claim_succeeds(ClaimData[3] memory _claimData) external {
        bytes32[] memory _leaves = _getLeaves(_claimData);

        bytes32[] memory _tree = _mockRoot(_leaves);

        for (uint256 _i = 0; _i < _claimData.length; _i++) {
            _mockErc20BalanceWithdrawCallAndSetExpectCall(
                _users[_i],
                _getErc20TokenBalances(
                    _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
                )
            );
            _mockEthBalanceWithdrawCallAndSetExpectCall(_users[_i], _claimData[_i].ethBalance);
            balanceClaimer.claim(
                merkleTreeGenerator.getProof(_tree, merkleTreeGenerator.getIndex(_tree, _leaves[_i])),
                _users[_i],
                _claimData[_i].ethBalance,
                _getErc20TokenBalances(
                    _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
                )
            );
        }
    }

    /// @dev Test that the claim function reverts when the user is not a legit claimer.
    function testFuzz_Claim_reverts(ClaimData[3] memory _claimData) external {
        bytes32[] memory _leaves = _getLeaves(_claimData);

        bytes32[] memory _tree = _mockRoot(_leaves);

        for (uint256 _i = 0; _i < _claimData.length; _i++) {
            IBalanceWithdrawer.Erc20BalanceClaim[] memory _erc20TokenBalances = _getErc20TokenBalances(
                _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
            );
            bytes32[] memory _proof =
                merkleTreeGenerator.getProof(_tree, merkleTreeGenerator.getIndex(_tree, _leaves[_i]));

            vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
            balanceClaimer.claim(_proof, makeAddr("random"), _claimData[_i].ethBalance, _erc20TokenBalances);
        }
    }
}
