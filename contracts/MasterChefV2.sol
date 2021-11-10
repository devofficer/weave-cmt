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
contract Stake is Ownable {
    using SafeMath for uint256;
    //using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 userPendingRewards;
    }
    

     // The WEAVE TOKEN!
    IERC20 public weave;
    
    // The BUSD TOKEN!
    IERC20 public busd;

    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;

    // Weave Tokens rewareded per block.
    uint256 public weavePerBlock;

   // Block number when bonus WEAVE period ends.
    uint256 public bonusEndBlock;


    // Total Weave Tokens to be distributed
    uint256 public TotalWeaveTokenRewards;

    // Delay Time Period
    uint256 public REWARD_PERIOD;

    // Bonus muliplier for early weave makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    //Pause state variable
    bool public isPaused = false;
   

    // Accumulated WEAVEs per share, times 1e12. See below.
    uint256 accWeavePerShare;
    
    // Last block number that WEAVEs distribution occurs.
    uint256 lastRewardBlock;
    
    event Deposit(address indexed user,uint256 amount);
    event Withdraw(address indexed user,uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event PoolUpdated(address updatedBy);
    event RewardsClaimed(address userAddress,uint256 rewards);
    event WeaveTokenDeposited(address indexed owner,uint256 amount,uint256 timetstamp);
    event PauseStatusChanged(address owner,uint256 timetstamp);
    
    
     constructor(
        IERC20 _weave,
        IERC20 _busd,
        uint256 _bonusEndBlock,
        uint256 _totalWeaveRewardsAmount,
        uint256 _rewardPeriod
    ) {
        weave = _weave;
        busd=_busd;
        bonusEndBlock = _bonusEndBlock;
        TotalWeaveTokenRewards=_totalWeaveRewardsAmount;
        REWARD_PERIOD = block.timestamp.add(_rewardPeriod);
        weavePerBlock =(_totalWeaveRewardsAmount*1e6)/(28800*_rewardPeriod);
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

    
    // View function to see pending rewards on frontend.
    function pendingWeave(address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        uint256 supply = busd.balanceOf(address(this));
        uint256  accRewardsPerShareTemp;
        if (block.number > lastRewardBlock && supply != 0) {
            uint256 multiplier =
                getMultiplier(lastRewardBlock, block.number);
          accRewardsPerShareTemp = accWeavePerShare.add((multiplier.mul(weavePerBlock)).mul(1e18).div(supply));
          
        }
        return user.amount.mul(accRewardsPerShareTemp).div(1e24).sub(user.rewardDebt).add(user.userPendingRewards);
    }


    // Update reward variables of the given pool to be up-to-date.
    function updatePool() public {
        if (block.number <=lastRewardBlock) {
            return;
        }
        uint256 supply = busd.balanceOf(address(this));
        if (supply == 0) {
            lastRewardBlock = block.number;
            return;
        }
         uint256 multiplier = getMultiplier(lastRewardBlock, block.number);
    
        accWeavePerShare = accWeavePerShare.add((multiplier.mul(weavePerBlock)).mul(1e18).div(supply));
        lastRewardBlock = block.number;
        
        emit PoolUpdated(msg.sender);
    }

    // Deposit BUSD tokens  for token rewards.
    function deposit(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(accWeavePerShare).div(1e24).sub(user.rewardDebt).add(user.userPendingRewards);
            if(pending > 0) {
                user.userPendingRewards = user.userPendingRewards.add(pending);
            }
        }
        if(_amount > 0) {
            busd.transferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        
        user.rewardDebt = user.amount.mul(accWeavePerShare).div(1e24);
        emit Deposit(msg.sender, _amount);
    }
    
    // claim pending weave tokens from protocol
    function claimRewards() public {
        require(block.timestamp>=REWARD_PERIOD,"Rewards claim hasnt been activated");
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        uint256 pending;
        if (user.amount > 0) {
             pending = user.amount.mul(accWeavePerShare).div(1e24).sub(user.rewardDebt).add(user.userPendingRewards);
            if(pending > 0) {
                safeWeaveTransfer(msg.sender, pending);
                user.userPendingRewards =0;
            }
        }
        
        user.rewardDebt = user.amount.mul(accWeavePerShare).div(1e24);
        
        emit RewardsClaimed(msg.sender,pending);
    }
    
    

    // Withdraw BUSD tokens from Stake.
    function withdraw(uint256 _amount) public {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        uint256 pending = user.amount.mul(accWeavePerShare).div(1e24).sub(user.rewardDebt).add(user.userPendingRewards);
        if(pending > 0 && (!isPaused)) {
            safeWeaveTransfer(msg.sender, pending);
            user.userPendingRewards = 0;
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            busd.transfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(accWeavePerShare).div(1e24);
        emit Withdraw(msg.sender,_amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        UserInfo storage user = userInfo[msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        busd.transfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, amount);
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

     // OWNER FUNCTIONS
    
       // Deposit Weave Tokens into smart contract
    function depositWeaveTokens(uint256 _amount) public onlyOwner {
         require(weave.approve(address(this), _amount),"Approval Failed");
         address owner = owner();
         weave.transferFrom(owner, address(this), _amount);
         emit WeaveTokenDeposited(owner,_amount,block.timestamp);
    }
    
    function startReward() public onlyOwner {
        REWARD_PERIOD = block.timestamp; 
        emit PauseStatusChanged(msg.sender,block.timestamp);
    }

     function delayReward() public onlyOwner {
        REWARD_PERIOD = block.timestamp.add(REWARD_PERIOD); 
        emit PauseStatusChanged(msg.sender,block.timestamp);
    }
  
    

}
