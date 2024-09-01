// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDeltaLibrary, BalanceDelta} from "v4-core/types/BalanceDelta.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

import {Hooks} from "v4-core/libraries/Hooks.sol";

contract PointsHook is BaseHook, ERC20 {
    // Use CurrencyLibrary and BalanceDeltaLibrary
    // to add some helper functions over the Currency and BalanceDelta
    // data types
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    // Keeping track of user => referrer
    mapping(address => address) public referredBy;

    // Amount of points someone gets for referring someone else
    uint256 public constant POINTS_FOR_REFERRAL = 500e18;

    // Initialize BaseHook and ERC20
    constructor(IPoolManager _manager, string memory _name, string memory _symbol)
        BaseHook(_manager)
        ERC20(_name, _symbol, 18)
    {}

    // Set up hook permissions to return `true`
    // for the two hook functions we are using
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // Stub implementation of `afterSwap`
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata swapParams,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyByPoolManager returns (bytes4, int128) {
        if (!swapParams.zeroForOne) return (this.afterSwap.selector, 0);
        if (!key.currency0.isNative()) return (this.afterSwap.selector, 0);

        // remember that negative amounts/delta meaning tokens that needs to be transferred from user to the pool
        // and positive amounts/delta meaning tokens that needs to be transferred from the pool to the user
        // and if swapParams.amountSpecified is negative, it means that the user wants to spend the maximum amount of tokens
        // and if swapParams.amountSpecified is positive, it means that the user wants to get the specified amount of tokens, which means, that the balance delta should be negative
        uint256 spendAmount =
            swapParams.amountSpecified < 0 ? uint256(-swapParams.amountSpecified) : uint256(int256(-delta.amount0()));

        // 20% of the spend amount will be given as points
        uint256 pointForSwap = spendAmount / 5;

        _dispatchPoints(hookData, pointForSwap);

        return (this.afterSwap.selector, 0);
    }

    function _dispatchPoints(bytes calldata data, uint256 userPoints) internal {
        // If no referrer/referree specified, no points will be assigned to anyone
        if (data.length == 0) return;

        // Decode the data to get the user and referrer
        (address referrer, address user) = abi.decode(data, (address, address));

        if (user == address(0)) {
            // If the user is the zero address, return
            return;
        }

        // set the referrer for the user
        if (referrer != address(0) && referredBy[user] == address(0)) {
            referredBy[user] = referrer;
            _mint(referrer, POINTS_FOR_REFERRAL);
        }

        if (referredBy[user] != address(0)) {
            // If the user has no referrer, return
            // mint 10% of the points to the referrer
            _mint(referrer, userPoints / 10);
        }

        // mint point for user
        _mint(user, userPoints);
    }

    // Stub implementation for `afterAddLiquidity`
    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override onlyByPoolManager returns (bytes4, BalanceDelta) {
        if (!key.currency0.isNative()) return (this.afterAddLiquidity.selector, delta);
        uint256 liquidityAdded = uint256(int256(-delta.amount0()));
        _dispatchPoints(hookData, liquidityAdded);

        return (this.afterAddLiquidity.selector, delta);
    }
}
