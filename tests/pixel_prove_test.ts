import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can mint a new photo NFT",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('pixel-prove', 'mint-photo', [
                types.ascii("Beautiful Sunset"),
                types.ascii("A stunning sunset captured at the beach"),
                types.ascii("Canon EOS R5"),
                types.ascii("Malibu Beach"),
                types.ascii("ipfs://Qm...")
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        
        // Verify metadata
        let metadata = chain.callReadOnlyFn(
            'pixel-prove',
            'get-photo-metadata',
            [types.uint(1)],
            deployer.address
        );
        
        metadata.result.expectSome().expectTuple();
    }
});

Clarinet.test({
    name: "Can list and purchase photo NFT",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        const price = 1000;
        
        // Mint NFT
        let block = chain.mineBlock([
            Tx.contractCall('pixel-prove', 'mint-photo', [
                types.ascii("Test Photo"),
                types.ascii("Test Description"),
                types.ascii("Test Camera"),
                types.ascii("Test Location"),
                types.ascii("ipfs://test")
            ], deployer.address)
        ]);
        
        // List NFT
        block = chain.mineBlock([
            Tx.contractCall('pixel-prove', 'list-photo', [
                types.uint(1),
                types.uint(price)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Purchase NFT
        block = chain.mineBlock([
            Tx.contractCall('pixel-prove', 'purchase-photo', [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Verify new owner
        let newOwner = chain.callReadOnlyFn(
            'pixel-prove',
            'get-owner',
            [types.uint(1)],
            deployer.address
        );
        
        assertEquals(newOwner.result.expectSome(), wallet1.address);
    }
});