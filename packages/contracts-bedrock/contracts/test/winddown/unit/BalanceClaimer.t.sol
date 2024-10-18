// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// libraries
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Testing
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { BalanceClaimer_Initializer } from "../../CommonTest.t.sol";
import { MerkleTreeGenerator } from "../../libraries/MerkleTreeGenerator.t.sol";

// Contracts
import { BalanceClaimer } from "../../../L1/winddown/BalanceClaimer.sol";
import { Proxy } from "../../../universal/Proxy.sol";

// Interfaces
import { IBalanceClaimer } from "../../../L1/interfaces/winddown/IBalanceClaimer.sol";
import { IErc20BalanceWithdrawer } from "../../../L1/interfaces/winddown/IErc20BalanceWithdrawer.sol";
import { IEthBalanceWithdrawer } from "../../../L1/interfaces/winddown/IEthBalanceWithdrawer.sol";

contract BalanceClaimer_Initialize_Test is BalanceClaimer_Initializer {
    /// @dev Test that the constructor sets the correct values.
    /// @notice Marked virtual to be overridden in
    ///         test/kontrol/deployment/DeploymentSummary.t.sol
    function test_constructor_succeeds() external virtual {
        assertEq(balanceClaimerImpl.root(), bytes32(0));
        assertEq(address(balanceClaimerImpl.ethBalanceWithdrawer()), address(0));
        assertEq(address(balanceClaimerImpl.erc20BalanceWithdrawer()), address(0));
    }

    /// @dev Test that the initialize function sets the correct values.
    function test_initialize_succeeds() external {
        vm.prank(multisig);
        balanceClaimerImpl = new BalanceClaimer();
        address mockOptimismPortal = makeAddr("mockOptimismPortal");
        address mockL1StandardBridge = makeAddr("mockL1StandardBridge");
        bytes32 mockRoot = bytes32(keccak256(abi.encode("root")));
        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeToAndCall(
            address(balanceClaimerImpl),
            abi.encodeWithSelector(BalanceClaimer.initialize.selector, mockOptimismPortal, mockL1StandardBridge, mockRoot)
        );
        assertEq(balanceClaimerProxy.root(), mockRoot);
        assertEq(address(balanceClaimerProxy.ethBalanceWithdrawer()), mockOptimismPortal);
        assertEq(address(balanceClaimerProxy.erc20BalanceWithdrawer()), mockL1StandardBridge);
    }
}

contract BalanceClaimer_Test is BalanceClaimer_Initializer {
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
        returns (IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _erc20Claim)
    {
        uint8 _length;
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _auxErc20TokenBalances =
            new IErc20BalanceWithdrawer.Erc20BalanceClaim[](3);

        if (_balanceToken1 > 0) {
            _length++;
            _auxErc20TokenBalances[0] =
                IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: _token1, balance: _balanceToken1 });
        }
        if (_balanceToken2 > 0) {
            _length++;
            _auxErc20TokenBalances[1] =
                IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: _token2, balance: _balanceToken2 });
        }
        if (_balanceToken3 > 0) {
            _length++;
            _auxErc20TokenBalances[2] =
                IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: _token3, balance: _balanceToken3 });
        }

        _erc20Claim = new IErc20BalanceWithdrawer.Erc20BalanceClaim[](_length);
        uint256 _index;
        for (uint256 _i = 0; _i < _auxErc20TokenBalances.length; _i++) {
            if (_auxErc20TokenBalances[_i].balance > 0) {
                _erc20Claim[_index] = _auxErc20TokenBalances[_i];
                _index++;
            }
        }
    }

    /// @dev Get the leaves for the merkle tree
    function _getLeaves(ClaimData[3] memory _claimData) internal view returns (bytes32[] memory _leaves) {
        _leaves = new bytes32[](_claimData.length);
        for (uint256 _i; _i < _claimData.length; _i++) {
            IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _erc20Claim = _getErc20TokenBalances(
                _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
            );
            _leaves[_i] = keccak256(
                bytes.concat(keccak256(abi.encode(_users[_i], _claimData[_i].ethBalance, _erc20Claim)))
            );
        }
    }

    /// @dev Generates the merkle tree, mock the root and set it in the storage
    function _mockRoot(bytes32[] memory _leaves) internal returns (bytes32[] memory _tree) {
        _tree = merkleTreeGenerator.generateMerkleTree(_leaves);
        bytes32 _root = _tree[0];
        stdstore.target(address(balanceClaimerProxy)).sig(IBalanceClaimer.root.selector).checked_write(_root);
    }

    /// @dev Mock the erc20 balance withdraw call and set the expect call if at least one balance is greater than 0
    function _mockErc20BalanceWithdrawCallAndSetExpectCall(
        address _user,
        IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _erc20Claim
    )
        internal
    {
        bool _called;
        for (uint256 _i = 0; _i < _erc20Claim.length; _i++) {
            if (_erc20Claim[_i].balance > 0) {
                _called = true;
                break;
            }
        }
        if (!_called) {
            return;
        }
        vm.mockCall(
            address(balanceClaimerProxy.erc20BalanceWithdrawer()),
            abi.encodeWithSelector(IErc20BalanceWithdrawer.withdrawErc20Balance.selector, _user, _erc20Claim),
            abi.encode(true)
        );

        vm.expectCall(
            address(balanceClaimerProxy.erc20BalanceWithdrawer()),
            abi.encodeWithSelector(IErc20BalanceWithdrawer.withdrawErc20Balance.selector, _user, _erc20Claim)
        );
    }

    /// @dev Mock the eth balance withdraw call and set the expect call if the balance is greater than 0
    function _mockEthBalanceWithdrawCallAndSetExpectCall(address _user, uint256 _ethBalance) internal {
        if (_ethBalance == 0) {
            return;
        }
        vm.mockCall(
            address(balanceClaimerProxy.ethBalanceWithdrawer()),
            abi.encodeWithSelector(IEthBalanceWithdrawer.withdrawEthBalance.selector, _user, _ethBalance),
            abi.encode(true)
        );

        vm.expectCall(
            address(balanceClaimerProxy.ethBalanceWithdrawer()),
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
            bool _canClaim = balanceClaimerProxy.canClaim(
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
            bool _canClaim = balanceClaimerProxy.canClaim(
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
    event BalanceClaimed(
        address indexed user, uint256 ethBalance, IErc20BalanceWithdrawer.Erc20BalanceClaim[] erc20TokenBalances
    );

    /// @dev Test that the canClaim function returns true when the user is a legit claimer.
    function testFuzz_claim_succeeds(ClaimData[3] memory _claimData) external {
        bytes32[] memory _leaves = _getLeaves(_claimData);

        bytes32[] memory _tree = _mockRoot(_leaves);

        for (uint256 _i = 0; _i < _claimData.length; _i++) {
            IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _erc20Claim = _getErc20TokenBalances(
                _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
            );
            _mockErc20BalanceWithdrawCallAndSetExpectCall(_users[_i], _erc20Claim);
            _mockEthBalanceWithdrawCallAndSetExpectCall(_users[_i], _claimData[_i].ethBalance);

            vm.expectEmit(address(balanceClaimerProxy));
            emit BalanceClaimed(_users[_i], _claimData[_i].ethBalance, _erc20Claim);

            balanceClaimerProxy.claim(
                merkleTreeGenerator.getProof(_tree, merkleTreeGenerator.getIndex(_tree, _leaves[_i])),
                _users[_i],
                _claimData[_i].ethBalance,
                _erc20Claim
            );
            assertTrue(balanceClaimerProxy.claimed(_users[_i]));
        }
    }

    /// @dev Test that the claim function reverts when the user is not a legit claimer.
    function testFuzz_claim_reverts(ClaimData[3] memory _claimData) external {
        bytes32[] memory _leaves = _getLeaves(_claimData);

        bytes32[] memory _tree = _mockRoot(_leaves);

        for (uint256 _i = 0; _i < _claimData.length; _i++) {
            IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _erc20Claim = _getErc20TokenBalances(
                _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
            );
            bytes32[] memory _proof =
                merkleTreeGenerator.getProof(_tree, merkleTreeGenerator.getIndex(_tree, _leaves[_i]));

            vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
            balanceClaimerProxy.claim(_proof, makeAddr("random"), _claimData[_i].ethBalance, _erc20Claim);
        }
    }

    /// @dev Test that the canClaim function can be only called once when the user is a legit claimer.
    function testFuzz_claimTwice_reverts(ClaimData[3] memory _claimData) external {
        bytes32[] memory _leaves = _getLeaves(_claimData);

        bytes32[] memory _tree = _mockRoot(_leaves);

        for (uint256 _i = 0; _i < _claimData.length; _i++) {
            IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _erc20Claim = _getErc20TokenBalances(
                _claimData[_i].balanceToken1, _claimData[_i].balanceToken2, _claimData[_i].balanceToken3
            );
            bytes32[] memory _proof =
                merkleTreeGenerator.getProof(_tree, merkleTreeGenerator.getIndex(_tree, _leaves[_i]));
            _mockErc20BalanceWithdrawCallAndSetExpectCall(_users[_i], _erc20Claim);
            _mockEthBalanceWithdrawCallAndSetExpectCall(_users[_i], _claimData[_i].ethBalance);

            balanceClaimerProxy.claim(_proof, _users[_i], _claimData[_i].ethBalance, _erc20Claim);
            assertTrue(balanceClaimerProxy.claimed(_users[_i]));

            vm.expectRevert(IBalanceClaimer.NoBalanceToClaim.selector);
            balanceClaimerProxy.claim(_proof, _users[_i], _claimData[_i].ethBalance, _erc20Claim);
        }
    }
}