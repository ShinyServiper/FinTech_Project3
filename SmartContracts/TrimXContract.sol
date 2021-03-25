// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.0;
//pragma solidity >= 0.5.0 < 0.6.0;



import "github.com/smartcontractkit/chainlink/blob/develop/evm-contracts/src/v0.6/ChainlinkClient.sol";     // for the chainlink client
//import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v2.5.0/contracts/math/SafeMath.sol";






contract PortfolioTokens is ChainlinkClient {                        // initializing the contract
    //using SafeMath for uint;                                       // allows us to use SafeMath for certain operations



    //----- Initializing Variables ------------//
address payable private minter;                                    // storing the owner's address as private variable
uint private lastRunTime_CoinValuation;                             // stores time when CoinValuation function was executed
uint private lastRunTime_CoinMinter;                                // stores time when CoinMinter function was executed

//------ Parameters needed for the Oracle ----------------//    
    uint256 public price;                                     // price of 1 ETH in USD (real time value from oracle)
    address private oracle;                    // oracle ID
    bytes32 private jobId; 
    uint256 private fee;






// Listing the Token types and the company Disclaimer
    string public our_disclaimer="(1) Risk Adverse\n(2)Risk Neutral\n(3) Risk Lover\n Disclaimer: Your money, your risk!";



//------ Generating Mapping to Display Exchange Rates (in ETH) for each Token----------//
    mapping (uint=> uint256) public exchange_rates;



//----- Defining the mappping for coin types----------//
    mapping (uint => uint256) public baskets;                     // initializing mapping for different coin baskets



//---- Defining the mapping for coin balances for users------//
    mapping(address => uint256[3]) balances;                      // Users can have any of the three coins


//----------------- NECESSARY MODIFIERS-------------------//
//--------------------------------------------------------//
//---- The is Minter Modifier----------//
modifier isMinter() {
//modifier to ensure that user is the Minter when using specific functions in the constract
    require(msg.sender == minter, "You are not the Coin Minter!");
     _;
}



//------- OnlyAfter modifier ----------//
//-------modifier which allows function to occur only after an amount of time has passed---------//
   modifier onlyAfter(uint _time) {                                                  // modifier that allows action after specific amount of time                                          
      require(
         now >= _time,                                                               // requirement of time 
         "Function called too early."
      );
      _;
   }






//---- The cost Modifier -------------//
//-----ensures the user has enough to cover the specific amount of tokens-------------//
//   modifier costs(uint price) {
//      if (msg.value >= price) {
//         _;
//      }
//   }
//require(msg.value>=amount_of_tokens/exchange_rates[token_type],"Note enough ETH to purchase requested number of tokens");

    
    /**
     * Network: Kovan
     * Oracle: 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e
     * Job ID: 29fa9aa13bf1468788b7cc4a500a45b8
     * Fee: 0.1 LINK
     */
     
     //-----The Initializing Function ------//
    constructor() public {
        minter=msg.sender;                                             // person who initializes contract becomes owner
        baskets[1]=100000;                                             // Initial Amount of Token1 tokens
        baskets[2]=100000;                                             // Initial Amount of Token2 tokens
        baskets[3]=900;                                                // Initial Amount of Token3 tokens
        
        // initialzing last exectution times
        lastRunTime_CoinValuation=now;                                           
        lastRunTime_CoinMinter=now;   



        //----- Initializing Exchange Rates (in ETH) for Tokens
        exchange_rates[1]=10;                           // Exchange rate for token 1 
        exchange_rates[2]=85;                           // Exchange rate for token 2 
        exchange_rates[3]=100;                           // Exchange rate for token 3
        
        
        //--------- Initializing values for oracle
        setPublicChainlinkToken();                           //set to public network
        oracle = 0x2f90A6D021db21e1B2A077c5a37B3C7E75D15b7e;
        jobId = "29fa9aa13bf1468788b7cc4a500a45b8";
        fee = 0.1 * 10 ** 18; // 0.1 LINK
    }
    
    
    
    
//------- Disclaimer -------------//
//---Function that displays the company disclaimer 
//function CompanyDisclaimer() external view returns (string memory) {
//    return our_disclaimer;                                    
//}

    

     
//-------- Calling  the Chainlink Oracle to compute value of tokens
     /**
     * Create a Chainlink request to retrieve API response, find the target
     * data, then multiply by 100 (to remove decimal places from data).
     */
    function CoinValuation() public isMinter onlyAfter(lastRunTime_CoinValuation + 30 seconds)  returns (bytes32 requestId)                                     // only minter can execute this function
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        //Instantiates a Request from the Chainlink contract
        // request variable is temporarily stored
        
        // Set the URL to perform the GET request on
        //request.add("get", "https://min-api.cryptocompare.com/data/pricemultifull?fsyms=USD&tsyms=ETH");
        request.add("get", "https://min-api.cryptocompare.com/data/price?fsym=ETH&tsyms=USD");
        request.add("path", "USD");    //obtaining USD value
        
        // Multiply the result by 100 to remove decimals
        int timesAmount = 100;
        request.addInt("times", timesAmount);
        lastRunTime_CoinValuation=now;                                          // update of lastRunTime_CoinValuation
        
        // Sends the request with specified oracle, constructed request and fee 
        // returns the ID of the request
        // used in process to make sure only that the address you want can call your Chainlink callback function.
        //but allows the target oracle to be specified. It requires an address, a Request, and an amount, and returns the requestId
        return sendChainlinkRequestTo(oracle, request, fee);
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
     //Used on fulfillment callbacks to ensure that the caller and requestId are valid.
    function fulfill(bytes32 _requestId, uint256 _price) public recordChainlinkFulfillment(_requestId)
    {
        price = _price;      // price of 1 ETH in USD
        uint ratio =1+(300000/price);                      // tells us how many ETH our portfolio is worth
        exchange_rates[1]=10*ratio;                           // Update of Exchange rate for token 1 
        exchange_rates[2]=85*ratio;                           // Update of Exchange rate for token 2 
        exchange_rates[3]=100*ratio;                           // Update of Exchange rate for token 3
        
        
    }
    
    
 //----------- CoinMinter function-------------//
// function that mints tokens. If amount of tokens are at or
// below threshold, then more coins are minted
// where only the owner will mint tokens
function CoinMinter ()  isMinter onlyAfter(lastRunTime_CoinMinter + 30 seconds) public  {
    for (uint i=1; i<4; i++){
        if (baskets[i]<=1000) {
        baskets[i]=baskets[i]+10000;                                                                  // mint 10000 more tokens for basket i=1,2,3
        }
    lastRunTime_CoinMinter=now;                                                                       // update of lastRunTime_CoinMinter
    }
}  
    
    
   
   
  
//----------- Withdraw function -----------------//
// deposits money to owner's/minter's wallet 
function  withdraw(uint _amount) isMinter public returns(uint){
    require(_amount<=address(this).balance,"Amount requested exceeds balance of contract!");              // ensures amount to withdraw is no more than balance of contract
    msg.sender.transfer(_amount);                                                                         // Transfer of funds to minter's wallet
    
    return address(this).balance;                                                                         // returns the balance of the contract
} 
    
    
    
    
    
 //--------- Function for User to Purchase coins------------//
// user will specify a token type, as well as an amount (no more than 100)
function coin_purchase  (uint token_type, uint amount_of_tokens) public payable {
    // limitation on number of tokens to Purchase
    require(amount_of_tokens <= 100, "You have exceeded the maximum number of tokens");
    
    // also token_type must be 1,2, or 3
    require(token_type<=3 && token_type>=1, "Please select a valid token type; must be 1,2, or 3");
    
    // ensures you have enough money for requested number of coins
    //require(msg.value>=amount_of_tokens/exchange_rates[token_type],"Note enough ETH to purchase requested number of tokens");
    
    
// Transfer coins when conditions are met
    // sending users their specified number of tokens for selected type
    balances[msg.sender][(token_type-1)]=balances[msg.sender][(token_type-1)]+amount_of_tokens;  // updating the user's balances of token
    baskets[token_type]=baskets[token_type]-amount_of_tokens;                                // updating available token amounts
    uint rem=msg.value-amount_of_tokens*exchange_rates[token_type];                          // computing remaining value
    
    
    //---Sends Remaining amount back to user------//
    if (rem>0){
        msg.sender.transfer(rem);
    }
}
   
   
   
    
//------- Check Contract Balance Function (Work in Progress) ----------//
// allows minter to check the contract balance
function CheckContractBalance() isMinter public view returns(uint) {
        return address(this).balance;
}




//---------- Fallback function    ---------//
//-----allows funds to be deposited to the account  -------//
receive() external payable{
    
}



 
//-----End of Contract  ----------//   