import { useArmenusConfig, useArmenusItems, type EmbedItem } from "@armenus/sdk-react";
import { Dish } from "./Dish";

const MERCHANT_ID = import.meta.env.VITE_ARMENUS_MERCHANT_ID as string | undefined;

export function Menu({
  selectedId,
  onSelect,
}: {
  selectedId: string | null;
  onSelect: (id: string | null) => void;
}) {
  /*
   * config() first, always.
   *
   * It is the only call that distinguishes "this key is revoked" from "this
   * menu is empty" — and without it, a bad key presents as a restaurant that
   * sells nothing, which is the single most confusing way for an integration
   * to fail.
   */
  const config = useArmenusConfig();

  const merchantId = MERCHANT_ID ?? config.data?.merchants[0]?.id ?? null;

  /*
   * `withModel: true` filters in the database, so `limit` counts dishes that
   * actually have a model. Filtering client-side would make a page of 20 come
   * back as however many of the first 20 happened to have one.
   */
  const items = useArmenusItems(merchantId, { withModel: true, limit: 24 });

  if (config.error) {
    return (
      <Problem
        title="That key did not work"
        detail={config.error.message}
        hint={
          config.error.isAuthError
            ? "Check VITE_ARMENUS_KEY. A revoked key and a wrong key look the same from here."
            : undefined
        }
      />
    );
  }

  if (config.loading || items.loading) {
    return <p className="status">Loading the menu…</p>;
  }

  if (items.error) {
    return <Problem title="Could not load dishes" detail={items.error.message} />;
  }

  const dishes = items.data ?? [];
  const selected = dishes.find((dish) => dish.id === selectedId) ?? null;

  if (selected) {
    return <Dish item={selected} onBack={() => onSelect(null)} />;
  }

  return (
    <div className="page">
      <header className="page-head">
        <p className="eyebrow">{config.data?.ownerName}</p>
        <h1>Menu</h1>
        <p className="muted">
          {dishes.length} {dishes.length === 1 ? "dish" : "dishes"} you can put on your
          table.
        </p>
      </header>

      {dishes.length === 0 ? (
        <Problem
          title="No dishes with models yet"
          detail="This merchant has no dishes with a ready 3D model."
          hint="That is a normal state, not an error — models are built after upload."
        />
      ) : (
        <ul className="grid">
          {dishes.map((dish) => (
            <li key={dish.id}>
              <Card item={dish} onOpen={() => onSelect(dish.id)} />
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

function Card({ item, onOpen }: { item: EmbedItem; onOpen: () => void }) {
  /*
   * The card shows the poster, not the 3D viewer.
   *
   * Deliberate: <model-viewer> is ~300 kB plus a mesh per instance, and
   * mounting twenty of them to render thumbnails would cost several megabytes
   * to show what a still image already shows. The viewer belongs on the detail
   * screen, where the user has asked for it.
   */
  const poster = item.model?.posterUrl ?? item.imageUrl;

  return (
    <button type="button" className="card" onClick={onOpen}>
      <span className="card-media">
        {poster ? (
          <img src={poster} alt="" loading="lazy" />
        ) : (
          <span className="card-blank" aria-hidden="true" />
        )}
      </span>
      <span className="card-body">
        <span className="card-name">{item.name}</span>
        <span className="card-price">
          {(item.priceCents / 100).toLocaleString(undefined, {
            style: "currency",
            currency: item.merchant.currency,
          })}
        </span>
      </span>
      {!item.isAvailable ? (
        <span className="card-flag">Not available today</span>
      ) : null}
    </button>
  );
}

function Problem({
  title,
  detail,
  hint,
}: {
  title: string;
  detail: string;
  hint?: string;
}) {
  return (
    <div className="problem">
      <h2>{title}</h2>
      <p>{detail}</p>
      {hint ? <p className="muted">{hint}</p> : null}
    </div>
  );
}
