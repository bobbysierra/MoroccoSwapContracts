// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../game/Evangelist.sol";

contract MoroccoSwapFarm is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt0;
        uint256 rewardDebt1;
        uint256 rewardFarmDebt;
        uint256 rewardKythDebt;
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 lastRewardBlock;
        uint256 accPerShare0;
        uint256 accPerShare1;
        IERC20 rewardToken0;
        IERC20 rewardToken1;
        uint256 accFarmPerShare;
    }

    bool public paused;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Lp address with id
    mapping(address => uint256) public lpIndex;
    mapping(address => bool) public lpStatus;
    // operator record
    mapping(address => bool) public operator;

    IERC20 public kyth; // kyth token
    // Verified lp pools farm reward
    mapping(address => bool) public whiteListedPool;
    uint256 public totalWhiteListedPool;

    // Evangelist Info
    address public evangeList;
    uint256 public currentId = 1;
    uint256[] public creditLevel = [1, 2, 3, 5, 8, 9, 12, 15, 20, 25];
    struct Credit {
        uint256 totalCreditsPoints;
        uint256 amount;
    }
    mapping(uint256 => Credit) public creditPointsInfo;

    struct evangelist {
        uint256 points; // total credit user earned in sepecific duration
        uint256 earnAmount;
        bool withdrawn; // default false.
    }
    mapping(address => mapping(uint256 => evangelist)) public evangelistInfo;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event AddReward(
        address lp,
        address rewardToken0,
        address rewardToken1,
        uint256 reward0,
        uint256 reward1
    );
    event Claim(
        address indexed user,
        uint256 indexed pid,
        uint256 reward0,
        uint256 reward1
    );
    event Paused();
    event UnPaused();
    event AddOperator(address _operator);
    event RemoveOperator(address _operator);
    event AddLpInfo(
        IERC20 _lpToken,
        IERC20 _rewardToken0,
        IERC20 _rewardToken1
    );
    event AddLpInfo(IERC20 _lpToken);
    event AddWhiteListPools(IERC20 _lpToken);
    event AddFarmReward(
        uint256 totalReward,
        uint256 totalPools,
        uint256 reward,
        uint256 lossReward
    );
    event ClaimEvangelistKyth(
        address rewardToken,
        uint256 round,
        uint256 reward
    );
    event ClaimFarmKyth(address rewardToken, uint256 pid, uint256 reward);
    event AddEvangeListReward(uint256 reward, uint256 id);

    modifier isPaused() {
        require(!paused, "contract Locked");
        _;
    }

    modifier isPoolExist(uint256 poolId) {
        require(poolId < poolLength(), "pool not exist");
        _;
    }

    modifier isOperator() {
        require(operator[msg.sender], "only operator");
        _;
    }

    function addWhiteListLPInfo(IERC20[] calldata _lpToken) public isOperator {
        for (uint256 i = 0; i < _lpToken.length; i++) {
            if (!whiteListedPool[address(_lpToken[i])]) {
                whiteListedPool[address(_lpToken[i])] = true;
                totalWhiteListedPool = totalWhiteListedPool.add(1);
                emit AddWhiteListPools(_lpToken[i]);
            }
        }
    }

    // Update reward variables
    function addFarmReward(uint256 totalReward) public isOperator {
        uint256 totalPools = totalWhiteListedPool;
        require(totalPools > 0, "pool list is empty");
        kyth.transferFrom(msg.sender, address(this), totalReward);
        uint256 amount = totalReward.div(totalPools);
        uint256 pending;
        for (uint256 i = 0; i < totalPools; i++) {
            PoolInfo storage pool = poolInfo[i];
            uint256 lpSupply = pool.lpToken.balanceOf(address(this));
            if (lpSupply != 0) {
                pool.accFarmPerShare = pool.accFarmPerShare.add(
                    amount.mul(1e12).div(lpSupply)
                );
            } else {
                pending = pending.add(amount);
            }
        }
        if (pending > 0) {
            kyth.transfer(msg.sender, pending);
        }

        emit AddFarmReward(totalReward, totalPools, amount, pending);
    }

    constructor(
        address _factory,
        address _owner,
        address _evangeList,
        address _kyth
    ) public {
        require(_factory != address(0x000), "zero address");
        require(address(_owner) != address(0x000), "zero address");

        operator[_factory] = true;
        operator[_owner] = true;
        evangeList = _evangeList;
        transferOwnership(_owner);
        emit AddOperator(_factory);
        kyth = IERC20(_kyth);
    }

    function addLPInfo(
        IERC20 _lpToken,
        IERC20 _rewardToken0,
        IERC20 _rewardToken1
    ) public isOperator {
        if (!lpStatus[address(_lpToken)]) {
            uint256 currentIndex = poolLength();
            poolInfo.push(
                PoolInfo({
                    lpToken: _lpToken,
                    lastRewardBlock: block.number,
                    accPerShare0: 0,
                    accPerShare1: 0,
                    rewardToken0: _rewardToken0,
                    rewardToken1: _rewardToken1,
                    accFarmPerShare: 0
                })
            );
            lpIndex[address(_lpToken)] = currentIndex;
            lpStatus[address(_lpToken)] = true;
            emit AddLpInfo(_lpToken, _rewardToken0, _rewardToken1);
        }
    }

    function addrewardtoken(
        address _lp,
        address token,
        uint256 amount
    ) public {
        uint256 _pid = lpIndex[_lp];
        PoolInfo storage pool = poolInfo[_pid];

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            IERC20(token).transferFrom(msg.sender, owner(), amount);
            return;
        }

        if (amount > 0) {
            if (token == address(pool.rewardToken0)) {
                pool.rewardToken0.transferFrom(
                    msg.sender,
                    address(this),
                    amount
                );
                pool.accPerShare0 = pool.accPerShare0.add(
                    amount.mul(1e12).div(lpSupply)
                );
            } else if (token == address(pool.rewardToken1)) {
                pool.rewardToken1.transferFrom(
                    msg.sender,
                    address(this),
                    amount
                );
                pool.accPerShare1 = pool.accPerShare1.add(
                    amount.mul(1e12).div(lpSupply)
                );
            }
        }

        pool.lastRewardBlock = block.number;
        emit AddReward(address(pool.lpToken), token, address(0x000), amount, 0);
    }

    // Update reward variables of the given pool to be up-to-date.
    function addReward(
        address _lp,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1
    ) public {
        uint256 _pid = lpIndex[_lp];
        PoolInfo storage pool = poolInfo[_pid];

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        uint256 reward0;
        uint256 reward1;
        if (address(pool.rewardToken0) == token0) {
            reward0 = amount0;
            reward1 = amount1;
        } else {
            reward0 = amount1;
            reward1 = amount0;
        }

        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            pool.rewardToken0.transferFrom(msg.sender, owner(), reward0);
            pool.rewardToken1.transferFrom(msg.sender, owner(), reward1);
            return;
        }

        if (reward0 > 0) {
            pool.rewardToken0.transferFrom(msg.sender, address(this), reward0);
            pool.accPerShare0 = pool.accPerShare0.add(
                reward0.mul(1e12).div(lpSupply)
            );
        }
        if (reward1 > 0) {
            pool.rewardToken1.transferFrom(msg.sender, address(this), reward1);
            pool.accPerShare1 = pool.accPerShare1.add(
                reward1.mul(1e12).div(lpSupply)
            );
        }
        pool.lastRewardBlock = block.number;
        emit AddReward(
            address(pool.lpToken),
            address(pool.rewardToken0),
            address(pool.rewardToken1),
            reward0,
            reward1
        );
    }

    function deposit(uint256 _pid, uint256 _amount)
        public
        isPaused
        isPoolExist(_pid)
    {
        require(_amount > 0, "zero amount");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount > 0) {
            claimReward(_pid);
        }
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt0 = user.amount.mul(pool.accPerShare0).div(1e12);
        user.rewardDebt1 = user.amount.mul(pool.accPerShare1).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function claimReward(uint256 _pid) public isPaused isPoolExist(_pid) {
        address _userAddr = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_userAddr];
        uint256 pendingReward0;
        uint256 pendingReward1;

        if (user.amount > 0) {
            pendingReward0 = user.amount.mul(pool.accPerShare0).div(1e12).sub(
                user.rewardDebt0
            );
            safeRewardTransfer(pool.rewardToken0, _userAddr, pendingReward0);
            pendingReward1 = user.amount.mul(pool.accPerShare1).div(1e12).sub(
                user.rewardDebt1
            );
            safeRewardTransfer(pool.rewardToken1, _userAddr, pendingReward1);
            //add points to upline
            addCreditPoints(_userAddr);
        }
        user.rewardDebt0 = user.amount.mul(pool.accPerShare0).div(1e12);
        user.rewardDebt1 = user.amount.mul(pool.accPerShare1).div(1e12);
        emit Claim(_userAddr, _pid, pendingReward0, pendingReward1);
    }

    function addCreditPoints(address user) internal {
        address upline = user;
        for (uint256 i = 0; i < 10; i++) {
            upline = Evangelist(evangeList).getReferral(upline);
            if (upline != address(0x00)) {
                evangelistInfo[upline][currentId].points =
                    evangelistInfo[upline][currentId].points +
                    creditLevel[i];
                creditPointsInfo[currentId].totalCreditsPoints =
                    creditPointsInfo[currentId].totalCreditsPoints +
                    creditLevel[i];
            }
        }
    }

    function claimFarmKyth(uint256 _pid) public isPaused {
        require(
            whiteListedPool[address(poolInfo[_pid].lpToken)],
            "Pool not whitelist"
        );
        address _userAddr = msg.sender;
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_userAddr];
        uint256 pendingReward;

        if (user.amount > 0) {
            pendingReward = user.amount.mul(pool.accFarmPerShare).div(1e12).sub(
                user.rewardFarmDebt
            );
            safeRewardTransfer(kyth, _userAddr, pendingReward);
        }
        user.rewardFarmDebt = user.amount.mul(pool.accFarmPerShare).div(1e12);
        emit ClaimFarmKyth(_userAddr, _pid, pendingReward);
    }

    function withdraw(uint256 _pid, uint256 _amount)
        public
        isPaused
        isPoolExist(_pid)
    {
        require(_amount > 0, "zero amount");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        if (user.amount > 0) {
            claimReward(_pid);
            if (whiteListedPool[address(poolInfo[_pid].lpToken)]) {
                claimFarmKyth(_pid);
            }
        }

        user.amount = user.amount.sub(_amount);
        user.rewardDebt0 = user.amount.mul(pool.accPerShare0).div(1e12);
        pool.lpToken.safeTransfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public isPoolExist(_pid) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt0 = 0;
        user.rewardDebt1 = 0;
    }

    // Safe transfer function
    function safeRewardTransfer(
        IERC20 _reward,
        address _to,
        uint256 _amount
    ) internal {
        uint256 _rewardBal = _reward.balanceOf(address(this));
        if (_amount > _rewardBal) {
            _reward.transfer(_to, _rewardBal);
        } else {
            _reward.transfer(_to, _amount);
        }
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function pause() external isOperator {
        require(!paused, "already paused");
        paused = true;
        emit Paused();
    }

    function unPause() external isOperator {
        require(!paused, "already unPaused");
        paused = false;
        emit UnPaused();
    }

    function addOperator(address _addr) external onlyOwner {
        operator[_addr] = true;
        emit AddOperator(_addr);
    }

    function removeOperator(address _addr) external onlyOwner {
        operator[_addr] = false;
        emit RemoveOperator(_addr);
    }

    function addEvangeListReward(uint256 totalReward)
        public
        isPaused
        isOperator
    {
        kyth.transferFrom(msg.sender, address(this), totalReward);

        if (currentId == 1 && (creditPointsInfo[currentId].amount == 0)) {
            creditPointsInfo[currentId].amount = totalReward;
        } else {
            currentId = currentId + 1;
            creditPointsInfo[currentId].amount = totalReward;
        }
        emit AddEvangeListReward(totalReward, currentId);
    }

    function claimEvangelistKyth(uint256 round) public isPaused {
        require(round < currentId, "invalid evangelist claim");
        address _userAddr = msg.sender;
        require(
            evangelistInfo[_userAddr][round].points > 0,
            "No credit points"
        );
        require(
            !evangelistInfo[_userAddr][round].withdrawn,
            "Already withdrawn"
        );
        uint256 reward = evangelistInfo[_userAddr][round].points.mul(
            (
                creditPointsInfo[round].amount.div(
                    creditPointsInfo[round].totalCreditsPoints
                )
            )
        );

        if (reward > 0) {
            evangelistInfo[_userAddr][round].earnAmount = reward;
            evangelistInfo[_userAddr][round].withdrawn = true;
            safeRewardTransfer(kyth, _userAddr, reward);
        }

        emit ClaimEvangelistKyth(_userAddr, round, reward);
    }

    function setEvangelist(address _evange) external isOperator {
        require(_evange != address(0x00), "Zero address");
        evangeList = _evange;
    }

    function getEvangeListReward(uint256 round, address _userAddr)
        external
        view
        returns (uint256 reward)
    {
        reward = evangelistInfo[_userAddr][round].points.mul(
            (
                creditPointsInfo[round].amount.div(
                    creditPointsInfo[round].totalCreditsPoints
                )
            )
        );
        return reward;
    }
}
