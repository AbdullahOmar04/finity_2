// functions/src/index.ts

import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();

// 1️⃣ Define the shape of our incoming data
interface ClaimOfferData {
  offerId: string;
}

// 2️⃣ Create the Callable in v2 style
export const claimOffer = onCall(
  // optional options (region, memory, etc)
  { region: "us-central1" },
  async (request) => {
    const { data, auth } = request;  // v2 bundles both here

    // — Auth check —
    if (!auth) {
      throw new Error("unauthenticated: You must be signed in.");
    }
    const uid = auth.uid;

    // — Validate incoming data —
    const { offerId } = data as ClaimOfferData;
    if (typeof offerId !== "string" || !offerId.trim()) {
      throw new Error("invalid-argument: Missing or invalid offerId.");
    }

    const db = admin.firestore();
    const offerRef   = db.collection("offers").doc(offerId);
    const claimerRef = db.collection("users").doc(uid);

    // — Transaction —
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(offerRef);
      if (!snap.exists) {
        throw new Error("not-found: Offer not found");
      }
      const { creatorUid, claimedCount, maxClaims, amountPerClaimCents } =
        snap.data() as {
          creatorUid: string;
          claimedCount: number;
          maxClaims: number;
          amountPerClaimCents: number;
        };

      if (claimedCount >= maxClaims) {
        throw new Error("failed-precondition: All spots claimed");
      }

      const senderRef = db.collection("users").doc(creatorUid);
      // read sender & claimer
      const [senderSnap, claimerSnap] = await Promise.all([
        tx.get(senderRef),
        tx.get(claimerRef),
      ]);

      if (!senderSnap.exists || !claimerSnap.exists) {
        throw new Error(
          "not-found: Sender or claimer user document missing"
        );
      }

      const senderBal = (senderSnap.data()!.balanceCents as number) || 0;
      if (senderBal < amountPerClaimCents) {
        throw new Error(
          "failed-precondition: Sender has insufficient funds"
        );
      }

      // schedule updates
      tx.update(offerRef, { claimedCount: claimedCount + 1 });
      tx.update(senderRef, {
        balanceCents:
          admin.firestore.FieldValue.increment(-amountPerClaimCents),
      });
      tx.update(claimerRef, {
        balanceCents:
          admin.firestore.FieldValue.increment(amountPerClaimCents),
      });
    });

    // 3️⃣ Return to client
    return { success: true };
  }
);
