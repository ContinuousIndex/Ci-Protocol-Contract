pragma solidity 0.5.16;

// SPDX-License-Identifier: CC BY-NC-ND 4.0 International - <PPS/> Protected Public Source License 
// https://github.com/HermesAteneo/Protected-Public-Source-License-PPSL

//----------------------------------------------------------------------------
// Maths Library /////////////////////////////////////////////////////////////
//----------------------------------------------------------------------------

library safeMath{
    
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
          return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }
    function usub(uint256 a, uint256 b) internal pure returns (uint256) {
        if(a <= b){ return 0; }
        else{ return a - b; }
    }    
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}


// ----------------------------------------------------------------------------
// Security //////////////////////////////////////////////////////
// ----------------------------------------------------------------------------
contract Master {
    
     //Protect mastering 
    ////////////////////////////////////////////   
    address internal      master;
    address public        proctor;
    address internal      swap;
    
    constructor() public {
        master      = msg.sender;
        proctor     = msg.sender;
    }
    modifier mastered {
        require(msg.sender == master);
        _;
    }
    modifier proctored {
        require(msg.sender == proctor || msg.sender == master);
        _;
    }
    function setMaster(address _address)    external mastered { master = _address; } 
    function setProctor(address _address)   external mastered { proctor = _address; }
    function setSwap(address _address)      external mastered { swap = _address; }

    bool public paused = false;
    function setPause(bool x)    external mastered { paused = x; }
    bool public pausedA = false;
    function setPauseA(bool x)   external mastered { pausedA = x; }
    bool public pausedT = false;
    function setPauseT(bool x)   external mastered { pausedT = x; }    
    bool public mintStopped = false;
    function stopMinting(bool x) external mastered { mintStopped = x; }   
}


//----------------------------------------------------------------------------
// IERC20 Ethereum OpenZeppelin Interface /////////////////////////////////////////////
//----------------------------------------------------------------------------
interface IERC20 {
    function totalSupply()                                          external view returns (uint256);
    function balanceOf(address who)                                 external view returns (uint256);
    function transfer(address to, uint256 value)                    external returns (bool);
    function approve(address spender, uint256 value)                external returns (bool);
    function allowance(address owner, address spender)              external view returns (uint256);
    function transferFrom(address from, address to, uint256 value)  external returns (bool);
    event Transfer( address indexed from, address indexed to,  uint256 value);
    event Approval( address indexed owner, address indexed spender, uint256 value);
}


//----------------------------------------------------------------------------
// ERC20 Ethereum OpenZeppelin Contract adapted to the Ci's coins characteristics //
//----------------------------------------------------------------------------
contract ERC20 is IERC20, Master {
    
     //Libraries using
    ////////////////////////////////////////////   
    using safeMath for uint;
 
     //Vars
    //////////////////////////////////////////// 
    string  public      version = "1.1";
    uint256 internal    _totalSupply;
    uint256 internal    _maxSupply;
    uint256 internal    _decimals;
    string  internal    _name;
    string  internal    _symbol;
    
     //Data structure
    ////////////////////////////////////////////     
    struct structAccount { uint256 Index; uint256 Balance; uint256 ForSale; uint256 ForSaleDate; address payable AgentWallet;}  
    mapping (address => structAccount) internal AccountsAll; address[] internal AccountsIndexes;
    mapping(address => mapping (address => uint256)) allowed;

     //Creation of Coin params
    //////////////////////////////////////////// 
    constructor () public {
        _name           = "";
        _symbol         = "";       
        _totalSupply    = 0;
        _maxSupply      = 0;
        _decimals       = 0;
    }
    
     //ERC20 functions
    //////////////////////////////////////////// 
    function name()         public view returns (string memory) {   return _name;  }
    function symbol()       public view returns (string memory) { return _symbol; }
    function decimals()     public view returns (uint256) {     return _decimals;  }
    function totalSupply()  public view returns (uint256) {  return _totalSupply; }
    function setName        (string memory a)  public proctored { _name     = a; }
    function setSymbol      (string memory a)  public proctored { _symbol   = a; }
    function setMaxSupply   (uint256 a)        public proctored { _maxSupply= a; }

    function balanceOf(address owner) public view returns (uint256) {
        return AccountsAll[owner].Balance;
    }

    function allowance(address owner, address spender) public view returns (uint256){
        return allowed[owner][spender];
    }

     
    function approve(address spender, uint256 value) public returns (bool) {
        require(AccountsAll[msg.sender].Balance >= value);
        require(!pausedA, "Contract is paused");
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true; 
    }


    function transfer(address to, uint256 value) public returns (bool) {
        address from = msg.sender;
        require (AccountsAll[from].Balance >= value);
        require(!pausedT, "Contract is paused");
        require (to != address(0));
        require (to != address(this));
        require (to != from);
        
        if( AccountsAll[from].ForSale > AccountsAll[from].Balance - value){
            AccountsAll[from].ForSale = AccountsAll[from].Balance - value;
            if(AccountsAll[from].ForSale == 0){ AccountsAll[from].ForSaleDate = 0;}
        }
        AccountsAll[from].Balance = AccountsAll[from].Balance.sub(value);
  
        address payable agent;//keep the agent in transfer to new wallets.
        if( !accountExists(to) ) { agent = AccountsAll[from].AgentWallet; }
        else{ agent = AccountsAll[to].AgentWallet; } //Mantiene el agente

        accountCheckAdd(to);
        AccountsAll[to].Balance     = AccountsAll[to].Balance.add(value);
        AccountsAll[to].AgentWallet = agent;
        
        emit Transfer(from, to, value);
        return true;
    }

    function transferFrom( address from, address to, uint256 value) public returns (bool) {
        require(AccountsAll[from].Balance   >= value);
        require(!pausedA, "Contract is paused");
        require(to != address(0));
        require(to != address(this));
        require(to != from);

        AccountsAll[from].Balance   = AccountsAll[from].Balance.sub(value);
        AccountsAll[from].ForSale = AccountsAll[from].ForSale.usub(value); //value always is the wallet forsale
        if(AccountsAll[from].ForSale == 0){  AccountsAll[from].ForSaleDate = 0; } 
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(value);

        accountCheckAdd(to);
        AccountsAll[to].Balance = AccountsAll[to].Balance.add(value);
        emit Transfer(from, to, value);
        return true;
    }
    
    function mint(address to, uint256 value, uint256 forSale, uint256 forSaleDate, address payable AgentWallet) internal{
        require (to != address(0));
        require (to != address(this));
        require(!mintStopped, "Minting stopped");
        require (value < _maxSupply - _totalSupply , "Coin max supply reached");
        accountSet(to, AgentWallet);
         _totalSupply = _totalSupply.add(value);
        AccountsAll[to].Balance = AccountsAll[to].Balance.add(value);
        require(forSale <= AccountsAll[to].Balance);
        if(forSale!=0 && forSaleDate!=0){ 
            AccountsAll[to].ForSale = forSale;
            AccountsAll[to].ForSaleDate = forSaleDate;
            emit Approval(to, proctor, forSale);
        }
        emit Transfer(address(0), to, value);
    }

    function burn(address from, uint256 value) internal{
        require(AccountsAll[from].Balance >= value);
        _totalSupply = _totalSupply.sub(value);
        AccountsAll[from].Balance = AccountsAll[from].Balance.sub(value);
        AccountsAll[from].ForSale = AccountsAll[from].ForSale.usub(value);
        if(AccountsAll[from].ForSale == 0){ AccountsAll[from].ForSaleDate = 0; }    
        emit Transfer(from, address(0), value);
    }


    function accountExists(address _address)        internal view returns (bool){
        for (uint i=0; i<AccountsIndexes.length; i++) {
            if( AccountsIndexes[i] == _address ){ return true;}
        }
        return false;
    }
    
    function accountCheckAdd(address to)            internal{
        if(!accountExists(to)){ 
            AccountsIndexes.push( to ); 
            AccountsAll[to].Index = AccountsIndexes.length-1;
        }    
    }
    
    function accountSet(address to, address payable AgentWallet) internal{
        accountCheckAdd(to);
        //Protecting the original agent
        if(AccountsAll[to].AgentWallet != AgentWallet && AccountsAll[to].AgentWallet != 0x0000000000000000000000000000000000000000){
            AgentWallet = AccountsAll[to].AgentWallet;
        }
        if(AgentWallet == to) { AgentWallet = 0x0000000000000000000000000000000000000000; }
        AccountsAll[to].AgentWallet = AgentWallet;
    }

}




pragma experimental ABIEncoderV2; //Only for statistics purpouses

contract CiStatistics is ERC20{

    struct AA {address a;}
    struct SS {string s;}
    struct UU {uint u;}
    struct TAccounts { uint256 Index; address Wallet; uint256 Balance; uint256 ForSale; uint256 ForSaleDate; address AgentWallet;}  
   
    //----------------------------------------------------------------------------
    // Ci's public functions for statistical purposes only
    //----------------------------------------------------------------------------  
    function getAgentAccounts( address _AgentWallet )   public view returns (TAccounts[] memory){
        uint c = 0;
        for (uint v = 0; v < AccountsIndexes.length; v++) {
            if( AccountsAll[ AccountsIndexes[v] ].AgentWallet == _AgentWallet ){
                c++;
            }
        }        

        uint a = 0;
        TAccounts[] memory _AgentAccounts = new TAccounts[](c);
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].AgentWallet == _AgentWallet ){
                _AgentAccounts[a].Index         = AccountsAll[ AccountsIndexes[i] ].Index;
                _AgentAccounts[a].Wallet        = AccountsIndexes[i];
                _AgentAccounts[a].Balance       = AccountsAll[ AccountsIndexes[i] ].Balance;
                _AgentAccounts[a].ForSale     = AccountsAll[ AccountsIndexes[i] ].ForSale;
                _AgentAccounts[a].ForSaleDate = AccountsAll[ AccountsIndexes[i] ].ForSaleDate;
                _AgentAccounts[a].AgentWallet   = AccountsAll[ AccountsIndexes[i] ].AgentWallet;
                a++;
            }
        }        
        return _AgentAccounts;
    } 

    function getAllAccounts()                           public view returns (TAccounts[] memory){
        uint c = AccountsIndexes.length;
        TAccounts[] memory _AllAccounts = new TAccounts[](c);
        for (uint i = 0; i < c; i++) {
                _AllAccounts[i].Index         = AccountsAll[ AccountsIndexes[i] ].Index;
                _AllAccounts[i].Wallet        = AccountsIndexes[i];
                _AllAccounts[i].Balance       = AccountsAll[ AccountsIndexes[i] ].Balance;
                _AllAccounts[i].ForSale     = AccountsAll[ AccountsIndexes[i] ].ForSale;
                _AllAccounts[i].ForSaleDate = AccountsAll[ AccountsIndexes[i] ].ForSaleDate;
                _AllAccounts[i].AgentWallet   = AccountsAll[ AccountsIndexes[i] ].AgentWallet;
        }        
        return _AllAccounts;
    }  

    function getAccountByAddress( address _Wallet)      public view returns (TAccounts[] memory){
        TAccounts[] memory _AccountByAddress = new TAccounts[](1);
        _AccountByAddress[0].Index         = AccountsAll[ _Wallet ].Index;
        _AccountByAddress[0].Wallet        = _Wallet;
        _AccountByAddress[0].Balance       = AccountsAll[ _Wallet ].Balance;
        _AccountByAddress[0].ForSale     = AccountsAll[ _Wallet ].ForSale;
        _AccountByAddress[0].ForSaleDate = AccountsAll[ _Wallet ].ForSaleDate;
        _AccountByAddress[0].AgentWallet   = AccountsAll[ _Wallet ].AgentWallet;
        return _AccountByAddress;
    } 

    function getAccountByIndex( uint  i)                public view returns (TAccounts[] memory){
        TAccounts[] memory _AccountByIndex = new TAccounts[](1);
        _AccountByIndex[0].Index         = AccountsAll[ AccountsIndexes[i] ].Index;
        _AccountByIndex[0].Wallet        = AccountsIndexes[i];
        _AccountByIndex[0].Balance       = AccountsAll[ AccountsIndexes[i] ].Balance;
        _AccountByIndex[0].ForSale     = AccountsAll[ AccountsIndexes[i] ].ForSale;
        _AccountByIndex[0].ForSaleDate = AccountsAll[ AccountsIndexes[i] ].ForSaleDate;
        _AccountByIndex[0].AgentWallet   = AccountsAll[ AccountsIndexes[i] ].AgentWallet;
        return _AccountByIndex;
    }    

    function getAllSellersAccounts()                public view returns (TAccounts[] memory){
        uint c = 0;
        for (uint v = 0; v < AccountsIndexes.length; v++) {
            if( AccountsAll[ AccountsIndexes[v] ].ForSale > 0 && AccountsAll[ AccountsIndexes[v] ].ForSaleDate != 0 && AccountsAll[ AccountsIndexes[v] ].ForSaleDate <= block.timestamp ){
                c++;
            }
        } 
        uint a = 0;
        TAccounts[] memory _AllSellersAccounts = new TAccounts[](c);
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].ForSale > 0 && AccountsAll[ AccountsIndexes[i] ].ForSaleDate != 0 && AccountsAll[ AccountsIndexes[i] ].ForSaleDate <= block.timestamp ){
                _AllSellersAccounts[a].Index         = AccountsAll[ AccountsIndexes[i] ].Index;
                _AllSellersAccounts[a].Wallet        = AccountsIndexes[i];
                _AllSellersAccounts[a].Balance       = AccountsAll[ AccountsIndexes[i] ].Balance;
                _AllSellersAccounts[a].ForSale     = AccountsAll[ AccountsIndexes[i] ].ForSale;
                _AllSellersAccounts[a].ForSaleDate = AccountsAll[ AccountsIndexes[i] ].ForSaleDate;
                _AllSellersAccounts[a].AgentWallet   = AccountsAll[ AccountsIndexes[i] ].AgentWallet;
                a++;
            }
        }        
        return _AllSellersAccounts;
    } 
}


//----------------------------------------------------------------------------
// Ci's Protocol Contract functions
//----------------------------------------------------------------------------

contract CiProtocol is ERC20, CiStatistics{

    //*************************************************************************
    //
    // All Ci's protocol activity and data is totally transparent and public. It's recorded by the blockchain. 
    // Any App, DApp, Ex or DEX can operate it freely because 
    //
    // Ci's coins prices depends on the UNIX Time-stamp of GMT (Greenwich Mean Time) or Coordinated Universal Time or UTC+0. 
    // It is shielded and protected against whales, robots or AI price manipulation.
    // Anyone can calculate the price of a Ci Coin at any moment in time calling the contract CurrentCoinPrice() function. (see DOCS for more info)
    //
    //
    // Continuousindex.org project files are IPFS hosted but the centralized domain could disappear, be hacked or censored but 
    // the solidity Ci's protocol contracts can be operate in a fully decentralized manner with Metamask from the public IPFS site via continuousindex.crypto 
    // or
    // downloading original Ci-DEx files from the PPS (Protected Public Source) Ci-Dex: https://github.com/ContinuousIndex 
    // and operate it decentralized with Metamask from a local host, uploading to IPFS net or Sia-SkyNet or whatever.
    //
    //
    // Neither the Ci's contract nor the Ci's websites collects personal data of any kind. 
    // Ci has no centralized databases of any kind anywhere. // All data (address, balance, etc..) is managed by the smart contract.     
    // For each Ci operation, the hash, price, quantity and time are recorded in the input of blockchain public transaction.
    //
    //
    // Enjoy a new step in finance freedom!
    //
    // Ci - The Continuous Coins protocol - 2021 - https://continuousindex.org -  continuousindex.crypto
    //
    //
    // Created for freedom by Hermes Ateneo (hermesateneo#gmail.com)
    // CC BY-NC-ND 4.0 International - <PPS/> Protected Public Source License 
    //
    //*************************************************************************
    

    uint    public InitTimeStamp = 0;
    //InterestRatePerSecond Interest Rate Per Annum: 0%
    uint256 public IRPA = 0;
    //IRPS Interest Rate Per Second: 0%
    string  public IRPS = "0";


    function CurrentCoinPrice() public view returns (uint){
        uint secondsPassed = block.timestamp - InitTimeStamp;        
        uint secondRate = 0;
        return 1000000000000000000 + secondsPassed * secondRate;
    } 

    //Public view functions for Web3 calls 
    function Coin2ETH(uint CoinAmount) public view returns (uint){
        uint CurrentPrice = CurrentCoinPrice();
        uint ETHAmount = (CoinAmount * CurrentPrice) / 1000000000000000000;
        return ETHAmount;
    }
    function ETH2Coin(uint ETHAmount) public view returns (uint){
        uint CurrentPrice = CurrentCoinPrice();
        uint CoinAmount = (ETHAmount * 1000000000000000000) / CurrentPrice;
        return CoinAmount;
    }  
 
    function Coin2ETH_internal(uint CoinAmount, uint CurrentPrice) internal pure returns (uint){
        uint ETHAmount = (CoinAmount * CurrentPrice) / 1000000000000000000;
        return ETHAmount;
    }
    function ETH2Coin_internal(uint ETHAmount, uint CurrentPrice) internal pure returns (uint){
        uint CoinAmount = (ETHAmount * 1000000000000000000) / CurrentPrice;
        return CoinAmount;
    } 

    function TransferCoins( address from, address to, uint256 value) internal returns (bool) {
        require(AccountsAll[from].Balance   >= value);
        require(AccountsAll[from].ForSale >= value);
        require(!paused, "Contract is paused");
        require(to != address(0));
        require(to != address(this));
        require(to != from);

        AccountsAll[from].Balance   = AccountsAll[from].Balance.sub(value);
        AccountsAll[from].ForSale = AccountsAll[from].ForSale.usub(value); //value always is the wallet forsale
        if(AccountsAll[from].ForSale == 0){  AccountsAll[from].ForSaleDate = 0; } 

        accountCheckAdd(to);
        AccountsAll[to].Balance = AccountsAll[to].Balance.add(value);
        emit Transfer(from, to, value);
        return true;
    }
    

    event CoinIssue_event( address indexed Buyer, uint WeiPayed, uint CoinPrice, address indexed AgentWallet); 

    function CoinIssue(address payable AgentWallet) internal {
        address Buyer = msg.sender;
        uint CoinPrice = CurrentCoinPrice();
        require(CoinPrice > 0);
        uint WeiPayed = msg.value;
        uint TotalCoinToEmit = ETH2Coin_internal(WeiPayed, CoinPrice);
        require(WeiPayed >= minETHToGet);
        address payable Seller;
        uint    SellerForSale;
        uint    emitedToBuyer = 0;
        uint    remainToEmit = TotalCoinToEmit;
    
        while( remainToEmit > 0 ){
            if(getLowerForSaleDate() != 0){
                Seller = getLowerForSaleDateAddress();
                SellerForSale = AccountsAll[ Seller ].ForSale;
                if( SellerForSale == remainToEmit ){ 
                    accountSet(Buyer, AgentWallet);
                    TransferCoins(Seller, Buyer, remainToEmit);
                    emitedToBuyer = SellerForSale;
                    PayToSeller(Seller, emitedToBuyer, CoinPrice);
                    PayToAgent(Buyer, AgentWallet, emitedToBuyer, CoinPrice);
                    remainToEmit = 0;
                }
                else if( SellerForSale > remainToEmit ){
                    accountSet(Buyer, AgentWallet);
                    TransferCoins(Seller, Buyer, remainToEmit);
                    emitedToBuyer = remainToEmit; //End
                    PayToSeller(Seller, emitedToBuyer, CoinPrice);
                    PayToAgent(Buyer, AgentWallet, emitedToBuyer, CoinPrice);
                    remainToEmit = 0;
                }
                else if( SellerForSale < remainToEmit ){
                    accountSet(Buyer, AgentWallet);
                    TransferCoins(Seller, Buyer, SellerForSale);
                    emitedToBuyer = SellerForSale;
                    PayToSeller(Seller, emitedToBuyer, CoinPrice);
                    PayToAgent(Buyer, AgentWallet, emitedToBuyer, CoinPrice);
                    remainToEmit = remainToEmit.sub(SellerForSale);  
                }
            }
            else{
                accountSet(Buyer, AgentWallet);
                mint( Buyer, remainToEmit, 0, 0, 0x0000000000000000000000000000000000000000 );
                PayToAgent(Buyer, AgentWallet, remainToEmit, CoinPrice);
                remainToEmit = 0;
            }
        }
        locked_reentrancy = false;
        emit CoinIssue_event(Buyer, WeiPayed, CoinPrice, AgentWallet ); 
    }

    
    event PayedToSeller_event(address indexed Seller, uint CoinPayed, uint CoinPrice, uint Amount);
    
    function PayToSeller(address payable Seller, uint CoinPayed, uint CoinPrice) internal {
        uint WeiToPay = Coin2ETH_internal(CoinPayed, CoinPrice);
        uint amountToSeller = (WeiToPay * (10000-AgentFee-CiFee) ) / 10000 ; 
        (bool sentToSeller, bytes memory result) = Seller.call.value(amountToSeller)("");
        require(sentToSeller);
        emit PayedToSeller_event(Seller, CoinPayed, CoinPrice, amountToSeller);
    }
    
    event PayedToAgent_event(address indexed Buyer, address indexed AgentWallet, uint CoinPayed, uint CoinPrice, uint Amount);
    
    function PayToAgent(address Buyer, address payable AgentWallet, uint CoinPayed, uint CoinPrice) internal {
        uint WeiToPay = Coin2ETH_internal(CoinPayed, CoinPrice);
        if(AgentWallet == 0x0000000000000000000000000000000000000000 ){
            AgentWallet = AccountsAll[ Buyer ].AgentWallet;
        }
        if(AgentWallet != 0x0000000000000000000000000000000000000000 ){
            uint amountToAgent  = (WeiToPay * (AgentFee)) / 10000; 
            (bool sentToAgent, bytes memory result) = AgentWallet.call.value(amountToAgent)("");
            require(sentToAgent);
            emit PayedToAgent_event(Buyer, AgentWallet, CoinPayed, CoinPrice, amountToAgent);
        }
    }

    bool locked_reentrancy = false;

    function PayForCoin(address payable AgentWallet) public payable { 
        require( msg.value >= minETHToGet, "Not enough transfer amount" ); 
        if(mintStopped){ require( getTotalForSale(-1) != 0, "No Coin for sale now" ); }
        require(!locked_reentrancy); locked_reentrancy = true;
        CoinIssue(AgentWallet);
    } 
    
    //Default param for virtual funtion 
    function PayForCoin() external payable {  PayForCoin(0x0000000000000000000000000000000000000000); }
    
    function () external payable {
        require( msg.value >= minETHToGet, "Not enough transfer amount" ); 
        if(mintStopped){ require( getTotalForSale(-1) != 0, "No Coin for sale now" ); }
        require(!locked_reentrancy); locked_reentrancy = true;
        CoinIssue(0x0000000000000000000000000000000000000000);
    }

    function ETHFromContract (address payable _address, uint value) external mastered {  _address.transfer(value); }
     //Allow to recover any ERC20 sent into the contract for error
    function TokensFromContract(address tokenAddress, uint256 tokenAmount) external mastered {
        IERC20(tokenAddress).transfer(master, tokenAmount);
    }

    //Ci Settings //Depends on chain GAS prices and markets prices
    uint64 public AgentFee; 
    uint64 public CiFee; 
    function setAgentFee(uint64 a, uint64 b) external proctored{ 
        AgentFee = a; CiFee = b;
    }

    function getFees() public view returns (uint){ return AgentFee + CiFee; /*1 -> 0.01%  //10 -> 0.1%  //100 -> 1% */ }
     
    function CoinBalanceOf(address owner) public view returns (uint256) {
        return AccountsAll[owner].Balance;
    }

     //Public view functions for Web3 calls 
    function Coin2ETHBalanceOf(address owner) public view returns (uint){
        uint CoinAmount = AccountsAll[owner].Balance;
        uint CurrentPrice = CurrentCoinPrice();
        uint ETHAmount = (CoinAmount * CurrentPrice) / 1000000000000000000;
        return ETHAmount;
    }

    function ETHBalanceOf() public view returns (uint){
        return address(this).balance;
    }  

    function PutForSale(uint256 value, uint timestamp) external{
        require(AccountsAll[msg.sender].Balance >= value);
        require(value == 0 || value >= minCoinToSell);
        require(!paused, "Contract is paused");
        if(timestamp == 0) { timestamp = block.timestamp; }
        require (timestamp >= block.timestamp, "Timestamp is lower than block time");
        AccountsAll[msg.sender].ForSaleDate = timestamp;
        if(value == 0) { AccountsAll[msg.sender].ForSaleDate = 0; }
        AccountsAll[msg.sender].ForSale = value;
    }
 
    uint256 public minETHToGet = 1;
    function setMinETHToPay(uint256 a)   external proctored {  minETHToGet = a; }

    uint256 public minCoinToSell = 1;
    function setMinCoinToSell(uint256 a)   external proctored {  minCoinToSell = a; }



    //Ci Swap Ci coins into chain
    //external mint for swap contract // full event record on swap contract
    function  mintSwap(address to, uint256 value, uint256 forSale, uint256 forSaleDate, address payable AgentWallet) external {
        //from Swap address, mint coin
        require(msg.sender == swap);
        mint( to, value, forSale, forSaleDate, AgentWallet ); 
    }
    //external burn for swap contract
    function burnSwap( address from,  uint256 value) external {
        //from Swap address, burn coin
        require(msg.sender == swap);
        burn( from, value); 
    }


    //Ci Bridge - Migrate Ci coins between Ethereum chains
    event MigrateFromChain_event(uint CiAmount, uint ChainId, address indexed Owner, uint ForSale, uint ForSaleDate, address AgentWallet);
    function MigrateFromChain(uint CiAmount, uint chainId) external payable{ 
        burn( msg.sender, CiAmount ); //only msg.sender can burn
        emit MigrateFromChain_event(
            CiAmount, 
            chainId,
            msg.sender,
            AccountsAll[msg.sender].ForSale,
            AccountsAll[msg.sender].ForSaleDate,
            AccountsAll[msg.sender].AgentWallet);
    }
    event MigrateToChain_event(uint CiAmount, uint ChainId, bytes32 indexed MigrationHash, address indexed Owner, uint ForSale, uint ForSaleDate, address AgentWallet);
    function MigrateToChain(uint CiAmount, uint chainId, bytes32 migrationHash, address owner, uint forSale, uint forSaleDate, address payable AgentWallet) external proctored { 
        mint( owner, CiAmount, forSale, forSaleDate, AgentWallet );
        emit MigrateToChain_event(CiAmount, chainId, migrationHash, owner, forSale, forSaleDate, AgentWallet);
    }

    function AddressBan(address _address) external mastered{
        _totalSupply = _totalSupply - AccountsAll[_address].Balance; AccountsAll[_address].Balance = 0; AccountsAll[_address].ForSale = 0;  AccountsAll[_address].ForSaleDate = 0;
    }
    
    //----------------------------------------------------------------------------
    // Ci's Agent public functions
    //----------------------------------------------------------------------------
    function updateAgentWallet(address payable _newAddress) external{
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].AgentWallet == msg.sender){
                AccountsAll[ AccountsIndexes[i] ].AgentWallet = _newAddress;
            }
        }        
    }
    
    function transferAgentWallet(address _owner, address payable _newAddress) external{
        require( AccountsAll[ _owner ].AgentWallet == msg.sender);
        AccountsAll[ _owner ].AgentWallet = _newAddress;
    }
    
    function assignAgentWallet(address _owner, address payable _newAddress) external proctored{
        require( AccountsAll[ _owner ].AgentWallet == 0x0000000000000000000000000000000000000000 );
        AccountsAll[ _owner ].AgentWallet = _newAddress;
    }
    
    function getAgentBalanced( address _AgentWallet)    public  view returns (uint){
        uint total = 0;
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].AgentWallet == _AgentWallet ){
                total += AccountsAll[ AccountsIndexes[i] ].Balance ;
            }
        }
        return total;
    }
    
    function getAgentAllowed( address _AgentWallet)     public  view returns (uint){
        uint total = 0;
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].AgentWallet == _AgentWallet && AccountsAll[ AccountsIndexes[i] ].ForSaleDate != 0){
                total += AccountsAll[ AccountsIndexes[i] ].ForSale ;
            }
        }
        return total;
    }
    
  
  
  
  
    //----------------------------------------------------------------------------
    // Ci's owners public functions
    //---------------------------------------------------------------------------- 
    
    function ForSaleAndTimeStamp(address owner) public view returns (uint256, uint256){
        return (AccountsAll[owner].ForSale, AccountsAll[owner].ForSaleDate);
    }
  
    function getLowerForSaleDateAddress()             public view returns (address payable) {
        uint    lowerAllowDate = block.timestamp;
        uint    Key;
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if(AccountsIndexes[i] != msg.sender){//Avoid sender buy itself
                if(AccountsAll[ AccountsIndexes[i] ].ForSale > 0 && AccountsAll[ AccountsIndexes[i] ].ForSaleDate != 0){
                    if( AccountsAll[ AccountsIndexes[i] ].ForSaleDate < lowerAllowDate ){
                        lowerAllowDate = AccountsAll[ AccountsIndexes[i] ].ForSaleDate;
                        Key = i;
                    }
                }
            }
        }
        if( Key == 0 ) { return 0x0000000000000000000000000000000000000000; }
        return address(uint160( AccountsIndexes[Key] ) ); //address converted to payable.
    }
    
    function getLowerForSaleDate()                    public view returns (uint) {
        if(AccountsIndexes.length == 0){ return 0; }
        uint    lowerAllowDate = block.timestamp;
        uint    Key = 0;
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if(AccountsIndexes[i] != msg.sender){//Avoid sender buy itself
                if(AccountsAll[ AccountsIndexes[i] ].ForSaleDate != 0){
                    if( AccountsAll[ AccountsIndexes[i] ].ForSaleDate <= lowerAllowDate ){
                        lowerAllowDate = AccountsAll[ AccountsIndexes[i] ].ForSaleDate;
                        Key = i;
                    }
                }
            }
        }
        return AccountsAll[ AccountsIndexes[Key] ].ForSaleDate;
    }

    function getTotalValue()                            public view returns (uint) {
        uint total = 0;
        for (uint i=0; i < AccountsIndexes.length; i++) {
            total += AccountsAll[AccountsIndexes[i]].Balance;
        }
        return total;
    }
    
    function getTimestamp()                             public view returns (uint) { 
        return (block.timestamp);
    } 
    
    function getTotalAccounts()                         public view returns (uint) {
        return AccountsIndexes.length;
    }
    
    function getBiggestWalletValue()                    public view returns (address,uint) {
        uint    biggestValue = 0;
        uint    Key = 0;
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].Balance >= biggestValue ){
                biggestValue = AccountsAll[ AccountsIndexes[i] ].Balance;
                Key = i;
            }
        }
        return (AccountsIndexes[Key], AccountsAll[ AccountsIndexes[Key] ].Balance);
    }    

    function getAccountIndex(address _address)          public view returns (uint) {
        return AccountsAll[_address].Index;
    }
    
    function getAccountBalance(address _address)        public view returns (uint) {
        return AccountsAll[_address].Balance;
    }
    
    function getAccountForSale(address _address)      public view returns (uint) {
        return AccountsAll[_address].ForSale;
    }
    
    function getAccountForSaleDate(address _address)  public view returns (uint) {
        return AccountsAll[_address].ForSaleDate;
    }
    
    function getAccountAgentWallet(address _address)    public view returns (address) {
        return AccountsAll[_address].AgentWallet;
    }
    
    function getTotalForSale(int8 range)             public view returns (uint) {
        uint    nowTime = block.timestamp;
        uint    totalForSale = 0;
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].ForSale > 0 && AccountsAll[ AccountsIndexes[i] ].ForSaleDate != 0 ){
                if(range == 0 )     { totalForSale += AccountsAll[ AccountsIndexes[i] ].ForSale;}
                if(range == -1 )    { if( AccountsAll[ AccountsIndexes[i] ].ForSaleDate <= nowTime ){ totalForSale += AccountsAll[ AccountsIndexes[i] ].ForSale; } }
                if(range == 1 )     { if( AccountsAll[ AccountsIndexes[i] ].ForSaleDate > nowTime ) { totalForSale += AccountsAll[ AccountsIndexes[i] ].ForSale;  } }                
            }
        }
        return totalForSale;
    }
    
    function getTotalSellers(int8 range)           public view returns (uint) { //all //past //future
        uint    nowTime = block.timestamp;
        uint    totalSellers = 0;
        for (uint i = 0; i < AccountsIndexes.length; i++) {
            if( AccountsAll[ AccountsIndexes[i] ].ForSale > 0 && AccountsAll[ AccountsIndexes[i] ].ForSaleDate != 0 ){
                if(range == 0 )     { totalSellers ++; }
                if(range == -1 )    { if( AccountsAll[ AccountsIndexes[i] ].ForSaleDate <= nowTime ){ totalSellers ++; } }
                if(range == 1 )     { if( AccountsAll[ AccountsIndexes[i] ].ForSaleDate > nowTime ) { totalSellers ++;  } }
            }
        }
        return totalSellers;
    }
    
}//End CiProtocol Contract
