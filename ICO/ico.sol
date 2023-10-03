// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract XRenderIco is Ownable, ReentrancyGuard {
    using SafeMath for uint;
    // time epoch
    uint public timeStart = 1697292000;
    uint public timeEnd = 1697464800;
    uint public timeStartClaim = 1707464800;
    address public xrenderAddress = 0x617b76412bd9f3f80fe87d1533dc7017defa8ad1;
    // 10$
    uint256 minimumToBuy = 33333 * 10 ** 18;
    // 5000$
    uint256 maximumToBuy = 16666666 * 10 ** 18;
    address public constant etherAddress =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint public remaining = 415000000 * 10 ** 18;

    mapping(address => uint) public userAmount;
    mapping(address => bool) public userClaimed;
    mapping(address => XrenderRate) public accetpedToken;

    event UserBuyIco(address _user, uint256 _xRenderAmount);
    event UserClaimed(address _user, uint256 _xRenderAmount);

    // example xrender/eth = 0.000000172 => 172 with zoom 10^9
    // eth address = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    struct XrenderRate {
        uint rate;
        uint zoom;
    }

    constructor() Ownable() {}

    function buyIcoWithEther(uint256 amount) external payable nonReentrant {
        require(accetpedToken[etherAddress].rate!= 0,"The token you are trying to use is not accepted.");
        require(
            block.timestamp >= timeStart && block.timestamp <= timeEnd,
            "The ICO has not started yet. Please come back after the ICO has opened."
        );
        require(
            amount >= minimumToBuy && amount <= maximumToBuy,
            "The purchase amount is invalid. Please ensure the purchase amount is within the range of $10 to $5000."
        );
        uint etherRequired = estimateValue(etherAddress, amount);
        require(
            msg.value == etherRequired,
            "Invalid value. Please enter a valid value."
        );
        require(
            remaining - amount >= 0,
            "Insufficient Xrender tokens to make this transaction."
        );
        userAmount[msg.sender] += amount;
        remaining -= amount;
        emit UserBuyIco(msg.sender, amount);
    }

    function estimateValue(address token, uint amount) public view returns (uint) {
      return amount.mul(accetpedToken[token].rate).div(
                                accetpedToken[token].zoom
                            );
    }

    function buyIcoWithToken(
        address token,
        uint256 amount
    ) external nonReentrant {
        require(accetpedToken[token].rate!= 0,"The token you are trying to use is not accepted.");
        require(
            block.timestamp >= timeStart && block.timestamp <= timeEnd,
            "The ICO has not started yet. Please come back after the ICO has opened."
        );
        require(
            amount >= minimumToBuy && amount <= maximumToBuy,
            "The purchase amount is invalid. Please ensure the purchase amount is within the range of $10 to $5000."
        );
  
        
        require(
            /// need to approval first
            IERC20(token).transferFrom(
                msg.sender,
                address(this),
                estimateValue(token, amount)
            ),
            "Invalid value. Please enter a valid value."
        );
        require(
            remaining - amount >= 0,
            "Insufficient Xrender tokens to make this transaction."
        );
        userAmount[msg.sender] += amount;
        emit UserBuyIco(msg.sender, amount);
    }

    function withdraw(address token) external onlyOwner {
        if (token == etherAddress) {
            payable(owner()).transfer(address(this).balance);
        } else {
            IERC20(token).transfer(
                msg.sender,
                IERC20(token).balanceOf(address(this))
            );
        }
    }

    function claim() external nonReentrant {
        require(
            block.timestamp >= timeStartClaim,
            "The claiming process has not started yet or has ended. Please check the ICO timeline."
        );
        require(
            userClaimed[msg.sender] == false,
            "You have already claimed your tokens."
        );
        require(
            userAmount[msg.sender] > 0,
            "You did not participate in the ICO."
        );
        require(
            IERC20(xrenderAddress).balanceOf(address(this)) >=
                userAmount[msg.sender],
            "Insufficient balance."
        );
        IERC20(xrenderAddress).transfer(msg.sender, userAmount[msg.sender]);
        userClaimed[msg.sender] = true;
        emit UserClaimed(msg.sender, userAmount[msg.sender]);
    }

    function updateTimeStart(uint _timeStart) external onlyOwner {
        timeStart = _timeStart;
    }

    function updateTimeEnd(uint _timeEnd) external onlyOwner {
        timeEnd = _timeEnd;
    }

    function updateTimeClaim(uint _timeClaim) external onlyOwner {
        timeStartClaim = _timeClaim;
    }

    function updateMaximumToBuy(uint _maximumToBuy) external onlyOwner {
        maximumToBuy = _maximumToBuy;
    }

    function updateMinimumToBuy(uint _minimumToBuy) external onlyOwner {
        minimumToBuy = _minimumToBuy;
    }

    function updatePrice(
        address token,
        XrenderRate memory _xrenderRate
    ) external onlyOwner {
        accetpedToken[token] = _xrenderRate;
    }
     function updateXrenderContract(address _xrenderAddress) external onlyOwner {
        xrenderAddress = _xrenderAddress;
    }
}
