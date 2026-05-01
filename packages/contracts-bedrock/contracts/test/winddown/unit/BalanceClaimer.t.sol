// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

// libraries
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

contract BalanceClaimer_TestBase is BalanceClaimer_Initializer {
    address mockOptimismPortal = makeAddr("mockOptimismPortal");
    address mockL1StandardBridge = makeAddr("mockL1StandardBridge");
    bytes32 mockRoot = keccak256("mockRoot");

    function setUp() public virtual override {
        super.setUp();

        vm.prank(multisig);
        balanceClaimerImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: address(mockOptimismPortal),
            _erc20BalanceWithdrawer: address(mockL1StandardBridge),
            _root: mockRoot
        });

        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeTo(address(balanceClaimerImpl));
    }

}

contract BalanceClaimer_Constructor_Test is BalanceClaimer_TestBase {

    /// @dev Test that the constructor sets the correct values.
    function test_constructor_succeeds() external {
        assertEq(balanceClaimerProxy.ROOT(), mockRoot);
        assertEq(address(balanceClaimerProxy.ETH_BALANCE_WITHDRAWER()), mockOptimismPortal);
        assertEq(address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER()), mockL1StandardBridge);
    }
}

contract BalanceClaimer_Test is BalanceClaimer_TestBase {
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

        balanceClaimerImpl = new BalanceClaimer({
            _ethBalanceWithdrawer: address(mockOptimismPortal),
            _erc20BalanceWithdrawer: address(mockL1StandardBridge),
            _root: _root
        });
        vm.prank(multisig);
        Proxy(payable(address(balanceClaimerProxy))).upgradeTo(address(balanceClaimerImpl));
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
            address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER()),
            abi.encodeWithSelector(IErc20BalanceWithdrawer.withdrawErc20Balance.selector, _user, _erc20Claim),
            abi.encode(true)
        );

        vm.expectCall(
            address(balanceClaimerProxy.ERC20_BALANCE_WITHDRAWER()),
            abi.encodeWithSelector(IErc20BalanceWithdrawer.withdrawErc20Balance.selector, _user, _erc20Claim)
        );
    }

    /// @dev Mock the eth balance withdraw call and set the expect call if the balance is greater than 0
    function _mockEthBalanceWithdrawCallAndSetExpectCall(address _user, uint256 _ethBalance) internal {
        if (_ethBalance == 0) {
            return;
        }
        vm.mockCall(
            address(balanceClaimerProxy.ETH_BALANCE_WITHDRAWER()),
            abi.encodeWithSelector(IEthBalanceWithdrawer.withdrawEthBalance.selector, _user, _ethBalance),
            abi.encode(true)
        );

        vm.expectCall(
            address(balanceClaimerProxy.ETH_BALANCE_WITHDRAWER()),
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

contract BalanceClaimer_Clawback_Test is BalanceClaimer_TestBase {
    event Clawback(address indexed foundation, address indexed timelock);

    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant GTC = 0xDe30da39c46104798bB5aA3fe8B9e0e1F348163F;

    /// @dev Mock the four `balanceOf(bridge)` calls that {clawback} reads.
    function _mockTokenBalances(uint256 _dai, uint256 _usdc, uint256 _usdt, uint256 _gtc) internal {
        vm.mockCall(
            DAI,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(mockL1StandardBridge)),
            abi.encode(_dai)
        );
        vm.mockCall(
            USDC,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(mockL1StandardBridge)),
            abi.encode(_usdc)
        );
        vm.mockCall(
            USDT,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(mockL1StandardBridge)),
            abi.encode(_usdt)
        );
        vm.mockCall(
            GTC,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(mockL1StandardBridge)),
            abi.encode(_gtc)
        );
    }

    /// @dev Build the four-token claim array as {clawback} composes it.
    function _claims(uint256 _dai, uint256 _usdc, uint256 _usdt, uint256 _gtc)
        internal
        pure
        returns (IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _out)
    {
        _out = new IErc20BalanceWithdrawer.Erc20BalanceClaim[](4);
        _out[0] = IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: DAI, balance: _dai });
        _out[1] = IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: USDC, balance: _usdc });
        _out[2] = IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: USDT, balance: _usdt });
        _out[3] = IErc20BalanceWithdrawer.Erc20BalanceClaim({ token: GTC, balance: _gtc });
    }

    /// @dev Mock and expect `withdrawErc20Balance(_user, _claims)` against the bridge.
    function _expectErc20Withdraw(address _user, IErc20BalanceWithdrawer.Erc20BalanceClaim[] memory _claim)
        internal
    {
        bytes memory _data =
            abi.encodeWithSelector(IErc20BalanceWithdrawer.withdrawErc20Balance.selector, _user, _claim);
        vm.mockCall(mockL1StandardBridge, _data, abi.encode(true));
        vm.expectCall(mockL1StandardBridge, _data);
    }

    /// @dev Mock and expect `withdrawEthBalance(_user, _amount)` against the portal.
    function _expectEthWithdraw(address _user, uint256 _amount) internal {
        bytes memory _data =
            abi.encodeWithSelector(IEthBalanceWithdrawer.withdrawEthBalance.selector, _user, _amount);
        vm.mockCall(mockOptimismPortal, _data, abi.encode(true));
        vm.expectCall(mockOptimismPortal, _data);
    }

    /// @dev mockFoundation receives `bal/2`, mockTimelock receives `bal - bal/2` (so any odd-unit
    ///      remainder goes to mockTimelock). The ETH withdrawer is invoked only when its balance
    ///      is non-zero. This single fuzz subsumes the even/odd/zero-eth/all-zero cases.
    ///      `uint128` keeps `vm.deal` within the available test ETH budget.
    function testFuzz_clawback_splitsBalances(
        uint128 _eth,
        uint128 _dai,
        uint128 _usdc,
        uint128 _usdt,
        uint128 _gtc
    )
        external
    {
        vm.deal(mockOptimismPortal, _eth);
        _mockTokenBalances(_dai, _usdc, _usdt, _gtc);

        if (_eth != 0) {
            _expectEthWithdraw(mockFoundation, _eth / 2);
            _expectEthWithdraw(mockTimelock, _eth - _eth / 2);
        } else {
            vm.expectCall(
                mockOptimismPortal,
                abi.encodeWithSelector(IEthBalanceWithdrawer.withdrawEthBalance.selector),
                0
            );
        }

        _expectErc20Withdraw(
            mockFoundation, _claims(uint256(_dai) / 2, uint256(_usdc) / 2, uint256(_usdt) / 2, uint256(_gtc) / 2)
        );
        _expectErc20Withdraw(
            mockTimelock,
            _claims(
                uint256(_dai) - uint256(_dai) / 2,
                uint256(_usdc) - uint256(_usdc) / 2,
                uint256(_usdt) - uint256(_usdt) / 2,
                uint256(_gtc) - uint256(_gtc) / 2
            )
        );

        vm.expectEmit(address(balanceClaimerProxy));
        emit Clawback(mockFoundation, mockTimelock);

        BalanceClaimer(address(balanceClaimerProxy)).clawback();
    }

    /// @dev Permissionless: any caller can trigger the drain. The proxy admin
    ///      is excluded because OP's transparent proxy reverts when admin
    ///      calls a non-admin selector.
    function testFuzz_clawback_permissionless(address _caller) external {
        vm.assume(_caller != multisig);

        vm.deal(mockOptimismPortal, 100);
        _mockTokenBalances(0, 0, 0, 0);

        _expectEthWithdraw(mockFoundation, 50);
        _expectEthWithdraw(mockTimelock, 50);
        _expectErc20Withdraw(mockFoundation, _claims(0, 0, 0, 0));
        _expectErc20Withdraw(mockTimelock, _claims(0, 0, 0, 0));

        vm.prank(_caller);
        BalanceClaimer(address(balanceClaimerProxy)).clawback();
    }
}

contract BalanceClaimer_Constructor_UnsetReceiver_Test is BalanceClaimer_Initializer {
    /// @dev The constructor must reject `address(0)` for either receiver.
    function test_constructor_reverts_zeroFoundation() external {
        vm.expectRevert(IBalanceClaimer.UnsetReceiver.selector);
        new BalanceClaimer({
            _ethBalanceWithdrawer: makeAddr("eth"),
            _erc20BalanceWithdrawer: makeAddr("erc20"),
            _root: keccak256("mockRoot"),
            _foundation: address(0),
            _timelock: makeAddr("timelock")
        });
    }

    function test_constructor_reverts_zeroTimelock() external {
        vm.expectRevert(IBalanceClaimer.UnsetReceiver.selector);
        new BalanceClaimer({
            _ethBalanceWithdrawer: makeAddr("eth"),
            _erc20BalanceWithdrawer: makeAddr("erc20"),
            _root: keccak256("mockRoot"),
            _foundation: makeAddr("foundation"),
            _timelock: address(0)
        });
    }
}