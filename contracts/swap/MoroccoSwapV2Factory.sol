// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;

import './interfaces/IMoroccoSwapV2Factory.sol';
import './MoroccoSwapV2Pair.sol';
import './MoroccoSwapFeeTransfer.sol';
import './interfaces/IERC20.sol';


contract MoroccoSwapV2Factory is IMoroccoSwapV2Factory {
    uint256 public override constant PERCENT100 = 1000000; 
    address public override constant DEADADDRESS = 0x000000000000000000000000000000000000dEaD;

    address public override feeTo;
    address public override feeToSetter;
    address public router;

    address public override feeTransfer; // In out Tax receiver
    uint256 public override InoutTax = 12500 ; // Inout tax fee 
    uint256 public override swapTax = 2500; // swap tax fee 
    uint256 public override InOutTotalFee = 30000;
    // Up to 4 decimal
    uint256 public override lockFee = 2500; 
    bool public override pause = false;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    constructor(address _feeToSetter) public {
        require(_feeToSetter != address(0x000), "Zero address");
        feeToSetter = _feeToSetter;
       
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(MoroccoSwapV2Pair).creationCode);
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'MoroccoSwapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'MoroccoSwapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'MoroccoSwapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(MoroccoSwapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        MoroccoSwapV2Pair(pair).initialize(token0, token1, router);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        if(!pause){
           IFarm(MoroccoSwapFeeTransfer(feeTransfer).farm()).addLPInfo(IERC20(pair), IERC20(tokenA), IERC20(tokenB));
        }
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'MoroccoSwapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }

    function pauseFee(bool _newStatus) external {
        require(msg.sender == feeToSetter, 'MoroccoSwapV2: FORBIDDEN');
        require(_newStatus != pause, 'MoroccoSwapV2: INVALID');
        pause = _newStatus;
    }

    function setRouter(address _router) public override {
        require(tx.origin == feeToSetter, 'MoroccoSwapV2: FORBIDDEN');
        router = _router;
    }

    function setFeeTransfer(address _feeTransfer) public override {
        require(tx.origin == feeToSetter, 'MoroccoSwapV2: FORBIDDEN');
        feeTransfer = _feeTransfer;
    }

}
