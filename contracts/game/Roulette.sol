pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract Roulette is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public currentRound; // current round
    uint256 public maxGameDuration = 1 hours;
    IERC20 public token;
    bool private paused;

    struct Round {
        uint256 gameId;
        uint256 startTimestamp;
        uint256 closeTimestamp;
        uint256 rewardAmount;
        uint256 totalWinner;
    }

    struct User {
        mapping(uint256 => twist) spinCount; // total spin count
        uint256[] participatedRound;
        uint256 lastRound; // last round participted
        uint256 lastIndex; // last reward withdraw index
    }

    struct twist {
        uint256 red; // 0
        uint256 blue; //1
    }
    mapping(uint256 => Round) public roundInfo;
    mapping(address => User) public userInfo;
    mapping(address => bool) public operator;

    event AddRound(uint256 gameId, uint256 totalReward);
    event Spin(address user, uint256 gameId, uint256 position);
    event Claim(address user, uint256 amount);
    event Paused();
    event UnPaused();
    event SetOperator(address addr);

    modifier onlyOperatorOrOwner() {
        require(
            operator[msg.sender] == true || owner() == msg.sender,
            "Not operator/owner"
        );
        _;
    }

    modifier isPaused() {
        require(!paused, "contract Locked");
        _;
    }

    constructor(IERC20 _token) public {
        token = _token;
    }

    function addRound(uint256 amount) external onlyOperatorOrOwner {
        // Increment currentRound
        currentRound = currentRound + 1;
        roundInfo[currentRound] = Round(
            currentRound,
            block.timestamp,
            block.timestamp + maxGameDuration,
            amount,
            0
        );
        emit AddRound(currentRound, amount);
    }

    function spin() external isPaused {
        address user = msg.sender;
        require(
            roundInfo[currentRound].closeTimestamp > block.timestamp,
            "Closed"
        );

        bytes32 hashOfRandom = keccak256(
            abi.encodePacked(block.number, block.timestamp, currentRound)
        );
        uint256 winningNumber = uint256(hashOfRandom).mod(2);
        if (winningNumber == 0) {
            userInfo[user].spinCount[currentRound].red =
                userInfo[user].spinCount[currentRound].red +
                1;
        } else {
            userInfo[user].spinCount[currentRound].blue =
                userInfo[user].spinCount[currentRound].blue +
                1;
            roundInfo[currentRound].totalWinner =
                roundInfo[currentRound].totalWinner +
                1;
        }
        if (userInfo[user].lastRound != currentRound) {
            userInfo[user].lastRound = currentRound;
            userInfo[user].participatedRound.push(currentRound);
        }

        emit Spin(user, currentRound, winningNumber);
    }

    function claim() external isPaused {
        address user = msg.sender;
        require(
            roundInfo[currentRound].closeTimestamp < block.timestamp,
            "Closed"
        );
        require(
            userInfo[user].participatedRound.length > 0,
            "Only participants"
        );
        require(
            userInfo[user].participatedRound.length > userInfo[user].lastIndex,
            "No pending"
        );

        uint256 amount;
        uint256 roundId;
        for (
            uint256 i = userInfo[user].lastIndex;
            i < userInfo[user].participatedRound.length;
            i++
        ) {
            roundId = userInfo[user].participatedRound[i];
            uint256 count = userInfo[user].spinCount[roundId].blue;
            if (count > 0) {
                amount = amount.add(
                    count.mul(
                        (
                            roundInfo[roundId].rewardAmount.div(
                                roundInfo[roundId].totalWinner
                            )
                        )
                    )
                );
            }
        }

        safeTransfer(user, amount);
        emit Claim(user, amount);
    }

    // Safe transfer function
    function safeTransfer(address _to, uint256 _amount) private {
        uint256 _rewardBal = token.balanceOf(address(this));
        if (_amount > _rewardBal) {
            token.transfer(_to, _rewardBal);
        } else {
            token.transfer(_to, _amount);
        }
    }

    function getUserInfo(address user)
        external
        view
        returns (
            uint256[] memory totalParticipatedRound,
            uint256 lastRound,
            uint256 lastIndex
        )
    {
        totalParticipatedRound = userInfo[user].participatedRound;
        lastRound = userInfo[user].lastRound;
        lastIndex = userInfo[user].lastIndex;

        return (totalParticipatedRound, lastRound, lastIndex);
    }

    function getUserTotalSpin(address user, uint256 gameID)
        external
        view
        returns (uint256 red, uint256 blue)
    {
        red = userInfo[user].spinCount[gameID].red;
        blue = userInfo[user].spinCount[gameID].blue;
        return (red, blue);
    }

    function pause() external onlyOwner {
        require(!paused, "already paused");
        paused = true;
        emit Paused();
    }

    function unPause() external onlyOwner {
        require(!paused, "already unPaused");
        paused = false;
        emit UnPaused();
    }

    function setOperator(address _addr) external onlyOwner {
        require(_addr != address(0x000), "zero address");
        operator[_addr] = true;
        emit SetOperator(_addr);
    }

    function setRewardToken(address _token) external onlyOwner {
        require(_token != address(0x000), "zero address");
        token = IERC20(_token);
    }

    function setMaxGameDuration(uint256 _duration) external onlyOwner {
        maxGameDuration = _duration;
    }

    function inCaseTokensGetStuck(address[] memory _token) external onlyOwner {
        uint256 amount;
        for (uint256 i = 0; i < _token.length; i++) {
            amount = IERC20(_token[i]).balanceOf(address(this));
            IERC20(_token[i]).safeTransfer(msg.sender, amount);
        }
    }
}
