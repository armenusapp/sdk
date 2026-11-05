// Reserved slots only: React continues to own menu cards and navigation.
if (armenus.slug === "zburgerhouse")
  armenus.onChange(function () {
    var slot = armenus.slots.bottom;
    if (!slot) return;
    var language = armenus.language;
    var existing = slot.querySelector(".zbh-help");
    if (existing && existing.lang === language) return;
    var copy =
      language === "ar"
        ? ["ساعدني أختار", "وجبة بأقل من 15$", "حار ومشبع", "خفيف ونباتي"]
        : language === "fr"
          ? [
              "Aidez-moi à choisir",
              "Un repas à moins de 15 $",
              "Épicé et généreux",
              "Léger et végétalien",
            ]
          : ["Help me choose", "A meal under $15", "Spicy & filling", "Light & vegan"];
    var section = document.createElement("section");
    section.className = "zbh-help";
    section.lang = language;
    var title = document.createElement("strong");
    title.textContent = copy[0];
    section.append(title);
    var row = document.createElement("div");
    copy.slice(1).forEach(function (label, index) {
      var button = document.createElement("button");
      button.type = "button";
      button.textContent = label;
      button.onclick = function () {
        armenus.openAssistant(
          label +
            ". Explain why each dish matches. Suggest a drink and an optional side, respecting my budget and dietary preferences. Reply in " +
            language +
            ".",
        );
      };
      row.append(button);
    });
    section.append(row);
    if (existing) existing.replaceWith(section);
    else slot.append(section);
  });
