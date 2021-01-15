/*

    Copyright 2020 DODO ZOO.
    SPDX-License-Identifier: Apache-2.0

*/

pragma solidity 0.6.9;
pragma experimental ABIEncoderV2;

import {SafeMath} from "../lib/SafeMath.sol";
import {DecimalMath} from "../lib/DecimalMath.sol";
import {DODOMath} from "../lib/DODOMath.sol";
import {Types} from "../lib/Types.sol";
import {Storage} from "./Storage.sol";


/**
 * @title Pricing
 * @author DODO Breeder
 *
 * @notice DODO Pricing model
 */
contract Pricing is Storage {
    using SafeMath for uint256;

    // ============ R = 1 cases ============

    function _ROneSellBaseToken(uint256 amount, uint256 targetQuoteTokenAmount)
        internal
        view
        returns (uint256 receiveQuoteToken)
    {
        uint256 i = getOraclePrice();
        uint256 Q2 = DODOMath._SolveQuadraticFunctionForTrade(
            targetQuoteTokenAmount,
            targetQuoteTokenAmount,
            DecimalMath.mul(i, amount),
            false,
            _K_
        );
        // in theory Q2 <= targetQuoteTokenAmount
        // however when amount is close to 0, precision problems may cause Q2 > targetQuoteTokenAmount
        return targetQuoteTokenAmount.sub(Q2);
    }

    function _ROneBuyBaseToken(uint256 amount, uint256 targetBaseTokenAmount)
        internal
        view
        returns (uint256 payQuoteToken)
    {
        require(amount < targetBaseTokenAmount, "_ROneBuyBaseToken DODO_BASE_BALANCE_NOT_ENOUGH");
        uint256 B2 = targetBaseTokenAmount.sub(amount);
        payQuoteToken = _RAboveIntegrate(targetBaseTokenAmount, targetBaseTokenAmount, B2);
        return payQuoteToken;
    }

    // ============ R < 1 cases ============

    function _RBelowSellBaseToken(
        uint256 amount,
        uint256 quoteBalance,
        uint256 targetQuoteAmount
    ) internal view returns (uint256 receieQuoteToken) {
        uint256 i = getOraclePrice();
        uint256 Q2 = DODOMath._SolveQuadraticFunctionForTrade(
            targetQuoteAmount,
            quoteBalance,
            DecimalMath.mul(i, amount),
            false,
            _K_
        );
        return quoteBalance.sub(Q2);
    }

    function _RBelowBuyBaseToken(
        uint256 amount,
        uint256 quoteBalance,
        uint256 targetQuoteAmount
    ) internal view returns (uint256 payQuoteToken) {
        // Here we don't require amount less than some value
        // Because it is limited at upper function
        // See Trader.queryBuyBaseToken
        uint256 i = getOraclePrice();
        uint256 Q2 = DODOMath._SolveQuadraticFunctionForTrade(
            targetQuoteAmount,
            quoteBalance,
            DecimalMath.mulCeil(i, amount),
            true,
            _K_
        );
        return Q2.sub(quoteBalance);
    }

    function _RBelowBackToOne() internal view returns (uint256 payQuoteToken) {
        // important: carefully design the system to make sure spareBase always greater than or equal to 0
        uint256 spareBase = _BASE_BALANCE_.sub(_TARGET_BASE_TOKEN_AMOUNT_);
        uint256 price = getOraclePrice();
        uint256 fairAmount = DecimalMath.mul(spareBase, price);
        uint256 newTargetQuote = DODOMath._SolveQuadraticFunctionForTarget(
            _QUOTE_BALANCE_,
            _K_,
            fairAmount
        );
        return newTargetQuote.sub(_QUOTE_BALANCE_);
    }

    // ============ R > 1 cases ============


    function _RAboveBuyBaseToken(
        uint256 amount,
        uint256 baseBalance,
        uint256 targetBaseAmount
    ) internal view returns (uint256 payQuoteToken) {
// require(
//             false,
//             append(
//                 uintToString(amount),
//                 "_RAboveBuyBaseToken false DODO_BASE_BALANCE_NOT_ENOUGH",
//                 uintToString(_BASE_BALANCE_),
//                 uintToString(baseBalance),
//                 ""
//             )
//         );
        // baseBalance = _BASE_BALANCE_;
        require(amount < baseBalance, append(uintToString(amount),"_RAboveBuyBaseToken DODO_BASE_BALANCE_NOT_ENOUGH",uintToString(baseBalance),"",""));
       
         uint256 B2 = baseBalance.sub(amount);
        return _RAboveIntegrate(targetBaseAmount, baseBalance, B2);
// return 0;
    }

    function _RAboveSellBaseToken(
        uint256 amount,
        uint256 baseBalance,
        uint256 targetBaseAmount
    ) internal view returns (uint256 receiveQuoteToken) {
        // here we don't require B1 <= targetBaseAmount
        // Because it is limited at upper function
        // See Trader.querySellBaseToken
        uint256 B1 = baseBalance.add(amount);
        return _RAboveIntegrate(targetBaseAmount, B1, baseBalance);
    }

    function _RAboveBackToOne() internal view returns (uint256 payBaseToken) {
        // important: carefully design the system to make sure spareBase always greater than or equal to 0
        uint256 spareQuote = _QUOTE_BALANCE_.sub(_TARGET_QUOTE_TOKEN_AMOUNT_);
        uint256 price = getOraclePrice();
        uint256 fairAmount = DecimalMath.divFloor(spareQuote, price);
        uint256 newTargetBase = DODOMath._SolveQuadraticFunctionForTarget(
            _BASE_BALANCE_,
            _K_,
            fairAmount
        );
        return newTargetBase.sub(_BASE_BALANCE_);
    }

    function _RAboveBackToOne1() internal view returns (uint256 payBaseToken,uint256[] memory steps) {
        // important: carefully design the system to make sure spareBase always greater than or equal to 0
steps = new  uint256[](15) ;
        uint256 spareQuote = _QUOTE_BALANCE_.sub(_TARGET_QUOTE_TOKEN_AMOUNT_);
        uint256 price = getOraclePrice();
        uint256 fairAmount = DecimalMath.divFloor(spareQuote, price);
        (uint256 newTargetBase,uint256[] memory steps1) = DODOMath._SolveQuadraticFunctionForTarget1(
            _BASE_BALANCE_,
            _K_,
            fairAmount
        );
steps = steps1;
         steps[9]=spareQuote;
steps[8]=price;
steps[7]=fairAmount;
steps[6]=newTargetBase;
        return (newTargetBase.sub(_BASE_BALANCE_),steps);
    }

    // ============ Helper functions ============

    function getExpectedTarget() public view returns (uint256 baseTarget, uint256 quoteTarget) {
        uint256 Q = _QUOTE_BALANCE_;
        uint256 B = _BASE_BALANCE_;
        if (_R_STATUS_ == Types.RStatus.ONE) {
            return (_TARGET_BASE_TOKEN_AMOUNT_, _TARGET_QUOTE_TOKEN_AMOUNT_);
        } else if (_R_STATUS_ == Types.RStatus.BELOW_ONE) {
            uint256 payQuoteToken = _RBelowBackToOne();
            return (_TARGET_BASE_TOKEN_AMOUNT_, Q.add(payQuoteToken));
        } else if (_R_STATUS_ == Types.RStatus.ABOVE_ONE) {
            uint256 payBaseToken = _RAboveBackToOne();
            return (B.add(payBaseToken), _TARGET_QUOTE_TOKEN_AMOUNT_);
        }
    }

    function getExpectedTarget1() public view returns (uint256 baseTarget, uint256 quoteTarget,uint256[] memory steps) {
        uint256 Q = _QUOTE_BALANCE_;
        uint256 B = _BASE_BALANCE_;
       steps = new  uint256[](15) ;
        if (_R_STATUS_ == Types.RStatus.ONE) {
            return (_TARGET_BASE_TOKEN_AMOUNT_, _TARGET_QUOTE_TOKEN_AMOUNT_,steps);
        } else if (_R_STATUS_ == Types.RStatus.BELOW_ONE) {
            uint256 payQuoteToken = _RBelowBackToOne();
            return (_TARGET_BASE_TOKEN_AMOUNT_, Q.add(payQuoteToken),steps);
        } else if (_R_STATUS_ == Types.RStatus.ABOVE_ONE) {
            (uint256 payBaseToken,uint256[] memory steps1) = _RAboveBackToOne1();
steps = steps1;
steps[0]=3;steps[1]=payBaseToken;
            return (B.add(payBaseToken), _TARGET_QUOTE_TOKEN_AMOUNT_,steps);
        }
    }

    function getMidPrice() public view returns (uint256 midPrice) {
        (uint256 baseTarget, uint256 quoteTarget) = getExpectedTarget();
        if (_R_STATUS_ == Types.RStatus.BELOW_ONE) {
            uint256 R = DecimalMath.divFloor(
                quoteTarget.mul(quoteTarget).div(_QUOTE_BALANCE_),
                _QUOTE_BALANCE_
            );
            R = DecimalMath.ONE.sub(_K_).add(DecimalMath.mul(_K_, R));
            return DecimalMath.divFloor(getOraclePrice(), R);
        } else {
            uint256 R = DecimalMath.divFloor(
                baseTarget.mul(baseTarget).div(_BASE_BALANCE_),
                _BASE_BALANCE_
            );
            R = DecimalMath.ONE.sub(_K_).add(DecimalMath.mul(_K_, R));
            return DecimalMath.mul(getOraclePrice(), R);
        }
    }

    function _RAboveIntegrate(
        uint256 B0,
        uint256 B1,
        uint256 B2
    ) internal view returns (uint256) {
        uint256 i = getOraclePrice();
        return DODOMath._GeneralIntegrate(B0, B1, B2, i, _K_);
    }

    // function _RBelowIntegrate(
    //     uint256 Q0,
    //     uint256 Q1,
    //     uint256 Q2
    // ) internal view returns (uint256) {
    //     uint256 i = getOraclePrice();
    //     i = DecimalMath.divFloor(DecimalMath.ONE, i); // 1/i
    //     return DODOMath._GeneralIntegrate(Q0, Q1, Q2, i, _K_);
    // }
}
