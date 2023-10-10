// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract XRenderPresale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    // time epoch
    uint public timeStart = 1697292000;
    uint public timeEnd = 1697464800;
    uint public timeStartClaim = 1697630400;
    address public xrenderAddress =
        address(0x617B76412bD9f3f80FE87d1533dc7017Defa8AD1);

    address public constant etherAddress =
        address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    uint256 public remaining = 416_666_666 * 10**18;

    mapping(address => uint256) public userAmount;
    mapping(address => bool) public userClaimed;
    mapping(address => XrenderRate) public accetpedToken;

    event UserBuyIco(address _user, uint256 _xRenderAmount);
    event UserClaimed(address _user, uint256 _xRenderAmount);

    // example xrender/eth = 0.000000172 => 172 with zoom 10^9
    // eth address = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE
    struct XrenderRate {
        uint8 rate;
        uint zoom;
        uint256 minimumAmount;
        uint256 maximumAmount;
    }

    constructor(address owner) Ownable() {
        transferOwnership(owner);
        // we use USDC/ETH for the ico
        //// 1XRAI = 0.0000007 ETH
        accetpedToken[0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE]=XrenderRate({
            rate: 172,
            zoom: 10**9,
            minimumAmount:5 * 10 ** 16, // 0.05
            maximumAmount:3 * 10 ** 18 // 3 ETH
        });
        //// 1XRAI = 0.0003 USDC
        accetpedToken[0xaf88d065e77c8cC2239327C5EDb3A432268e5831]=XrenderRate({
            rate: 3,
            zoom: 10 ** 16,
            minimumAmount:10 * 10 ** 6 , // 10 USDC
            maximumAmount:5000 * 10 ** 6 // 5000 USDC
        });
    }

    function buyPresaleByEther(uint256 amountEther)
        external
        payable
        nonReentrant
    {
        require(
            accetpedToken[etherAddress].rate != 0,
            "The token you are trying to use is not accepted."
        );
        require(
            block.timestamp >= timeStart && block.timestamp <= timeEnd,
            "The ICO has not started yet. Please come back after the ICO has opened."
        );
        uint256 totalXrender = calculateXrenderAmount(
            etherAddress,
            amountEther
        );

        require(
            amountEther >= accetpedToken[etherAddress].minimumAmount &&
                amountEther <= accetpedToken[etherAddress].maximumAmount,
            "The purchase amount is invalid. Please ensure the purchase amount is within the range of $10 to $5000."
        );
        require(
            msg.value == amountEther,
            "Invalid value. Please enter a valid value."
        );
        require(
            remaining - totalXrender >= 0,
            "Insufficient Xrender tokens to make this transaction."
        );
        userAmount[msg.sender] += totalXrender;
        remaining -= totalXrender;
        emit UserBuyIco(msg.sender, totalXrender);
    }

    function calculateValue(address token, uint256 amount)
        public
        view
        returns (uint256)
    {
        return
            amount.mul(accetpedToken[token].rate).div(
                accetpedToken[token].zoom
            );
    }

    function calculateXrenderAmount(address token, uint256 tokenAmount)
        public
        view
        returns (uint256)
    {
        return
            tokenAmount.mul(accetpedToken[token].zoom).div(
                accetpedToken[token].rate
            );
    }

    function buyPresaleByToken(address token, uint256 amountToken)
        external
        nonReentrant
    {
        require(
            accetpedToken[token].rate != 0,
            "The token you are trying to use is not accepted."
        );
        require(
            block.timestamp >= timeStart && block.timestamp <= timeEnd,
            "The ICO has not started yet. Please come back after the ICO has opened."
        );
        uint256 totalXrender = calculateXrenderAmount(token, amountToken);

        require(
            amountToken >= accetpedToken[token].minimumAmount &&
                amountToken <= accetpedToken[token].maximumAmount,
            "The purchase amount is invalid. Please ensure the purchase amount is within the range of $10 to $5000."
        );

        require(
            /// need to approval first
            IERC20(token).transferFrom(msg.sender, address(this), amountToken),
            "Invalid value. Please enter a valid value."
        );
        require(
            remaining - totalXrender >= 0,
            "Insufficient Xrender tokens to make this transaction."
        );
        remaining -= totalXrender;
        userAmount[msg.sender] += totalXrender;
        emit UserBuyIco(msg.sender, totalXrender);
    }

    function withdraw(address token) external onlyOwner {
        if (token == etherAddress) {
            payable(owner()).transfer(address(this).balance);
        } else {
            require(IERC20(token).transfer(
                msg.sender,
                IERC20(token).balanceOf(address(this))
            ),"Transfer failed");
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
        require(IERC20(xrenderAddress).transfer(msg.sender, userAmount[msg.sender]),"Transfer failed");
        userClaimed[msg.sender] = true;
        emit UserClaimed(msg.sender, userAmount[msg.sender]);
    }

    function updateTimeStart(uint256 _timeStart) external onlyOwner {
        timeStart = _timeStart;
    }

    function updateTimeEnd(uint256 _timeEnd) external onlyOwner {
        timeEnd = _timeEnd;
    }

    function updateTimeClaim(uint256 _timeClaim) external onlyOwner {
        timeStartClaim = _timeClaim;
    }

    function updatePrice(address token, XrenderRate memory _xrenderRate)
        external
        onlyOwner
    {
        accetpedToken[token] = _xrenderRate;
    }

    function updateXrenderContract(address _xrenderAddress) external onlyOwner {
        xrenderAddress = _xrenderAddress;
    }
}
