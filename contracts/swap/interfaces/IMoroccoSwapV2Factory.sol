// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

interface IMoroccoSwapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeToSetter(address) external;
    function PERCENT100() external view returns (uint256);
    function DEADADDRESS() external view returns (address);
    
    function lockFee() external view returns (uint256);
    // function sLockFee() external view returns (uint256);
    function pause() external view returns (bool);
    function InoutTax() external view returns (uint256);
    function swapTax() external view returns (uint256);
    function setRouter(address _router) external ;
    function InOutTotalFee()external view returns (uint256);
    function feeTransfer() external view returns (address);

    function setFeeTransfer(address)external ;
    
}
