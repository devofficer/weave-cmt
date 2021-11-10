// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



// MasterChef is the master of Weave. He can make Weave and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once WEAVE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefV1 is Ownable {
    using SafeMath for uint256;
    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many BUSD tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of WEAVEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accWeavePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws BUSD tokens to a pool. Here's what happens:
        //   1. The pool's `accWeavePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }
    // Info of each pool.
    struct PoolInfo {
        IERC20 stakeToken; // Address of BUSD token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. WEAVEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that WEAVEs distribution occurs.
        uint256 accWeavePerShare; // Accumulated WEAVEs per share, times 1e12. See below.
    }
    // The WEAVE TOKEN!
    IERC20 public weave;
    
    // The BUSD TOKEN!
    IERC20 public busd;
    // Dev address.
    address public devaddr;
    // Block number when bonus WEAVE period ends.
    uint256 public bonusEndBlock;
    // WEAVE tokens created per block.
    uint256 public weavePerBlock;
    // Bonus muliplier for early weave makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    //Pause state variable
    bool public isPaused = true;
   
    // Info of each pool.
    PoolInfo[] public poolInfo;

    // Info of each user that stakes BUSD tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when WEAVE mining starts.
    uint256 public startBlock;
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event WeaveTokenDeposited(address indexed owner,uint256 amount,uint256 timetstamp);
    event PauseStatusChanged(address owner,uint256 timetstamp);

    constructor(
        IERC20 _weave,
        IERC20 _busd,
        address _devaddr,
        uint256 _weavePerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock,
        uint256 _allocPoint // can be 1000 WEAVE's to distribute 
    ) {
        weave = _weave;
        busd=_busd;
        devaddr = _devaddr;
        weavePerBlock = _weavePerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        
        
         // staking pool
        poolInfo.push(PoolInfo({
            stakeToken: _busd,
            allocPoint: _allocPoint,
            lastRewardBlock: startBlock,
            accWeavePerShare: 0
        }));

        totalAllocPoint = _allocPoint;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }


    // Update the given pool's WEAVE allocation point. Can only be called by the owner.
    function set(
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(
            _allocPoint
        );
        poolInfo[0].allocPoint = _allocPoint;
    }


    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return
                bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                    _to.sub(bonusEndBlock)
                );
        }
    }

    // View function to see pending WEAVEs on frontend.
    function pendingWeave(address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][_user];
        uint256 accWeavePerShare = pool.accWeavePerShare;
        uint256 lpSupply = pool.stakeToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 weaveReward =
                multiplier.mul(weavePerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accWeavePerShare = accWeavePerShare.add(
                weaveReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accWeavePerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool();
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        PoolInfo storage pool = poolInfo[0];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.stakeToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 weaveReward =
            multiplier.mul(weavePerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );
        // weave.mint(devaddr, weaveReward.div(10));
        // weave.mint(address(this), weaveReward);
        pool.accWeavePerShare = pool.accWeavePerShare.add(
            weaveReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit BUSD tokens to MasterChef for WEAVE allocation.
    function deposit(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool();
        if (user.amount > 0 && (!isPaused)) {
            uint256 pending =
                user.amount.mul(pool.accWeavePerShare).div(1e12).sub(
                    user.rewardDebt
                );
            safeWeaveTransfer(msg.sender, pending);
        }
        pool.stakeToken.transferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accWeavePerShare).div(1e12);
        emit Deposit(msg.sender, 0, _amount);
    }
    

    // Withdraw BUSD tokens from MasterChef.
    function withdraw(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        if(!isPaused){
            uint256 pending =
            user.amount.mul(pool.accWeavePerShare).div(1e12).sub(
                user.rewardDebt
            );
        safeWeaveTransfer(msg.sender, pending);
       }
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accWeavePerShare).div(1e12);
        pool.stakeToken.transfer(address(msg.sender), _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }


    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        pool.stakeToken.transfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, 0, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe weave transfer function, just in case if rounding error causes pool to not have enough WEAVEs.
    function safeWeaveTransfer(address _to, uint256 _amount) internal {
        uint256 weaveBal = weave.balanceOf(address(this));
        if (_amount > weaveBal) {
            weave.transfer(_to, weaveBal);
        } else {
            weave.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }

     // OWNER FUNCTIONS
    
       // Deposit Weave Tokens into smart contract
    function depositWeaveTokens(uint256 _amount) public onlyOwner {
         require(weave.approve(address(this), _amount),"Approval Failed");
         address owner = owner();
         weave.transferFrom(owner, address(this), _amount);
         emit WeaveTokenDeposited(owner,_amount,block.timestamp);
    }
    
    function changePauseStatus() public onlyOwner {
        if(isPaused){
            isPaused = false;
        }
        else {
            isPaused=true;
        }
        emit PauseStatusChanged(msg.sender,block.timestamp);
    }
  

}