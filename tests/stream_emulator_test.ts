import { Clarinet, Tx, Chain, Account, types } from 'https://deno.land/x/clarinet@v1.0.4/index.ts';
import { assertEquals } from 'https://deno.land/std@0.170.0/testing/asserts.ts';

Clarinet.test({
  name: "Stream Emulator: Create Token Stream",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const recipient = accounts.get('wallet_1')!;

    const block = chain.mineBlock([
      Tx.contractCall('stream-emulator', 'create-stream', [
        types.principal(recipient.address),
        types.principal(deployer.address),
        types.uint(1000),
        types.uint(10),
        types.uint(100)
      ], deployer.address)
    ]);

    assertEquals(block.receipts.length, 1);
    block.receipts[0].result.expectOk().expectUint(1);
  }
});

Clarinet.test({
  name: "Stream Emulator: Claim Stream Tokens",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const recipient = accounts.get('wallet_1')!;

    // First create stream
    const createBlock = chain.mineBlock([
      Tx.contractCall('stream-emulator', 'create-stream', [
        types.principal(recipient.address),
        types.principal(deployer.address),
        types.uint(1000),
        types.uint(10),
        types.uint(100)
      ], deployer.address)
    ]);

    // Then simulate time passing by mining blocks
    chain.mineEmptyBlock(50);

    // Try to claim tokens
    const claimBlock = chain.mineBlock([
      Tx.contractCall('stream-emulator', 'claim-stream-tokens', [
        types.uint(1)
      ], recipient.address)
    ]);

    assertEquals(claimBlock.receipts.length, 1);
    claimBlock.receipts[0].result.expectOk();
  }
});