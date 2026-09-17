import { ArmenusModel, type EmbedItem } from "@armenus/sdk-react";

export function Dish({ item, onBack }: { item: EmbedItem; onBack: () => void }) {
  return (
    <div className="page">
      <button type="button" className="back" onClick={onBack}>
        ← Menu
      </button>

      <ArmenusModel
        item={item}
        arLabel="See it on your table"
        onEnterAr={(dish) => {
          // Where your own analytics would go. Fires when the user actually
          // activates AR, not when the button is merely shown.
          console.info("AR opened", dish.id, dish.name);
        }}
        footer={(presentation) =>
          /*
           * `blockedOnConversion` is the one unsupported case worth a hopeful
           * message: it means the USDZ is still being produced and will exist
           * shortly. Every other reason is permanent for this session, and the
           * SDK has already put its own explanation above this footer.
           */
          presentation.ar.blockedOnConversion ? (
            <p className="note">
              The AR version is still being prepared — usually a minute or two.
            </p>
          ) : null
        }
      />

      <header className="dish-head">
        <h1>{item.name}</h1>
        <p className="dish-price">
          {(item.priceCents / 100).toLocaleString(undefined, {
            style: "currency",
            currency: item.merchant.currency,
          })}
        </p>
      </header>

      {item.description ? <p>{item.description}</p> : null}

      {item.tags.length > 0 ? (
        <ul className="tags">
          {item.tags.map((tag) => (
            <li key={tag}>{tag}</li>
          ))}
        </ul>
      ) : null}

      {item.model ? (
        <p className="muted small">
          Shown at actual size — {Math.round(item.model.physicalSizeM * 100)} cm across.
        </p>
      ) : null}
    </div>
  );
}
