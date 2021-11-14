    // SPDX-License-Identifier: MIT

    pragma solidity ^0.8.0;

    import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
    import "@openzeppelin/contracts/utils/math/SafeMath.sol";
    import "@openzeppelin/contracts/access/Ownable.sol";

    contract Stake is Ownable {
        using SafeMath for uint256;

        // The WEAVE TOKEN!
        IERC20 public weave;

        // The BUSD TOKEN!
        IERC20 public busd;

        // Deposit busd amount of user
        mapping (address => uint) public amountOf;

        // Weave Tokens rewareded per block.
        uint256 public weavePerBlock;

        // Total Weave Tokens to be distributed
        uint256 public totalWeaveTokenRewards;

        // Total amount of deposited BUSD
        uint256 public totalBusdAmount;

        // Block number that reward starts
        uint256 public rewardStartNumber;
        
        // Reward Period (in day)
        uint256 public rewardPeriod;

        // Block number that reward ends
        uint256 public rewardEndNumber;

        // Boolean variable to show if reward is ongoing
        bool public rewardOngoing = false;

        // Deposit or Withdrawal information
        struct DepositInfo {
            address userAddress;
            bool isDeposit;
            uint256 amount;
            uint256 totalAmount;
            uint256 blockNumber;
        }

        // Track of deposits and withdrawals
        DepositInfo[] public depositLog;
        
        event Deposit(address indexed user, uint256 amount);
        event Withdraw(address indexed user, uint256 amount);
        event RewardsClaimed(address userAddress, uint256 rewards);
        event WeaveTokenDeposited(address indexed owner, uint256 amount, uint256 timestamp);
        event RewardStarted(address owner, uint256 blocknumber);
        
        constructor(
            IERC20 _weave,
            IERC20 _busd,
            uint256 _totalWeaveRewardsAmount,
            uint256 _rewardPeriod // in days
        ) {
            weave = _weave;
            busd = _busd;
            totalWeaveTokenRewards = _totalWeaveRewardsAmount;
            rewardPeriod = _rewardPeriod;
            weavePerBlock = getWeavePerBlock();
        }
        
        // Get weave tokens per block
        function getWeavePerBlock() private view returns(uint256) {
            return totalWeaveTokenRewards.mul(1e6).div(28800).mul(rewardPeriod);
        }
        
        // View function to see current rewards on frontend.
        function currentReward(address _user) external view returns (uint256) {
            return calculateReward(_user, rewardStartNumber, block.number);
        }

        // Deposit BUSD tokens  for token rewards.
        function deposit(uint256 _amount) public {
            totalBusdAmount = totalBusdAmount.add(_amount);
            depositLog.push(DepositInfo({
                userAddress: msg.sender,
                isDeposit: true,
                amount: _amount,
                totalAmount: totalBusdAmount,
                blockNumber: block.number
            }));
            busd.transferFrom(address(msg.sender), address(this), _amount);
            emit Deposit(msg.sender, _amount);
        }
        
        // Withdraw BUSD tokens from Stake.
        function withdraw(uint256 _amount) public {
            uint256 userAmount = amountOf[msg.sender];
            require(userAmount >= _amount, "Not enough deposit amount");
            totalBusdAmount = totalBusdAmount.sub(_amount);
            depositLog.push(DepositInfo({
                userAddress: msg.sender,
                isDeposit: false,
                amount: _amount,
                totalAmount: totalBusdAmount,
                blockNumber: block.number
            }));
            busd.transfer(address(msg.sender), _amount);
            emit Withdraw(msg.sender,_amount);
        }

        // Claim pending weave tokens from protocol
        function claimRewards() public {
            require(block.number >= rewardEndNumber, "Reward is still ongoing");
            uint256 totalClaim = calculateReward(msg.sender, rewardStartNumber, rewardEndNumber);
            safeWeaveTransfer(msg.sender, totalClaim);
            emit RewardsClaimed(msg.sender, totalClaim);
        }

        // Calculate user's reward tokens between certian block numbers
        function calculateReward(address user, uint256 startBlock, uint256 endBlock) private view returns(uint256) {
            uint256 allocation;
            uint256 blcNumber;
            uint256 totalAlloc;
            for (uint256 i = 0; i < depositLog.length; i++) {
                uint256 priorAmount = depositLog[i].isDeposit
                    ? depositLog[i].totalAmount.add(depositLog[i].amount)
                    : depositLog[i].totalAmount.sub(depositLog[i].amount);
                if (block.number >= startBlock && block.number <= endBlock) {
                    totalAlloc = totalAlloc.add(
                        allocation * (depositLog[i].blockNumber - blcNumber)
                    );
                }
                allocation = user == depositLog[i].userAddress
                    ? (priorAmount * allocation / 100 + depositLog[i].amount) / depositLog[i].totalAmount * 100
                    : (priorAmount * allocation / 100) / depositLog[i].totalAmount * 100;
                blcNumber = depositLog[i].blockNumber;
            }
            uint256 totalClaim = weavePerBlock * totalAlloc / 1e8;
            return totalClaim;
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
            require(
                weave.approve(address(this), _amount),
                "Approval Failed"
            );
            require(!rewardOngoing, "Reward already started");
            address owner = owner();
            weave.transferFrom(owner, address(this), _amount);
            totalWeaveTokenRewards = totalWeaveTokenRewards.add(_amount);
            emit WeaveTokenDeposited(owner, _amount, block.timestamp);
            getWeavePerBlock();
        }
        
        // Trigger reward period
        function startReward() public onlyOwner {
            rewardOngoing = true;
            rewardStartNumber = block.number;
            emit RewardStarted(msg.sender, rewardStartNumber);
        }
        
        // Set or change reward period (in days)
        function setRewardPeriod(uint _newPeriod) public onlyOwner {
            require(!rewardOngoing, "Reward already started");
            rewardPeriod = _newPeriod;
            getWeavePerBlock();
        }
    }