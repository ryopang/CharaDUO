import Core
import StoreKit
import SwiftUI

/// Shown when a match is blocked because the games have run out, and from
/// Settings on request. Prices come from StoreKit so they're always the
/// player's local currency; the titles are ours so they follow the app's
/// language rather than whatever App Store Connect has localized.
struct PaywallView: View {
    @Environment(AppCoordinator.self) private var coordinator

    /// Called when the player has games again (after a purchase or restore).
    let onUnlocked: () -> Void
    let onDismiss: () -> Void

    private var store: StoreManager { coordinator.store }

    var body: some View {
        NavigationStack {
            ScrollableCenteredColumn {
                Spacer(minLength: 8)

                Image(systemName: "party.popper.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text(store.canStartGame ? "Get More Games" : "You're Out of Free Games")
                        .font(.title.bold())
                    Text(store.canStartGame
                         ? "Add games any time. They never expire."
                         : "You've played your 10 free games. Pick how you'd like to keep playing.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    offer(
                        product: store.unlimitedProduct,
                        title: "Unlimited Games",
                        detail: "Play as many matches as you like. One-time purchase.",
                        badge: "Best Value",
                        id: "paywall.unlimited"
                    )
                    offer(
                        product: store.packProduct,
                        title: "10 More Games",
                        detail: "Adds 10 matches. Buy again whenever you run out.",
                        badge: nil,
                        id: "paywall.pack"
                    )
                }
                .padding(.horizontal, 28)

                if !store.productsLoaded {
                    VStack(spacing: 8) {
                        if store.isLoadingProducts {
                            ProgressView()
                        } else {
                            Text("The store isn't available right now.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Try Again") { Task { await store.loadProducts() } }
                                .buttonStyle(.glass)
                        }
                    }
                }

                if let message = store.message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 28)
                }

                Button("Restore Purchases") { Task { await store.restore() } }
                    .font(.footnote)
                    .disabled(store.isPurchasing)

                Spacer(minLength: 8)
            }
            .padding()
            .background(Theme.backdrop.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now", action: onDismiss)
                }
            }
        }
        .task {
            store.message = nil
            if !store.productsLoaded { await store.loadProducts() }
        }
        .onChange(of: store.allowance.canStartGame) { _, canStart in
            if canStart { onUnlocked() }
        }
        .interactiveDismissDisabled(store.isPurchasing)
    }

    @ViewBuilder
    private func offer(
        product: Product?,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        badge: LocalizedStringKey?,
        id: String
    ) -> some View {
        let label = HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if let badge {
                    Text(badge)
                        .font(.caption2.bold())
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.pill)
                }
                Text(title).font(.headline)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(product?.displayPrice ?? "—")
                .font(.title3.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)

        Button {
            guard let product else { return }
            Task { await store.purchase(product) }
        } label: { label }
        .buttonStyle(.glass)
        .controlSize(.large)
        .disabled(product == nil || store.isPurchasing)
        .accessibilityIdentifier(id)
    }
}
