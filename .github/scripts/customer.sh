#!/bin/sh
set -eu
: "${ACTION:?}" "${CUSTOMER:?}"

CUSTOMER=$(printf '%s' "$CUSTOMER" | tr '[:upper:]' '[:lower:]')
echo "$CUSTOMER" | LC_ALL=C grep -Eq '^[a-z]{1,5}[0-9]{2,12}$' || { echo "customer number invalid: $CUSTOMER"; exit 1; }
ADDRESS=$(printf '%s' "${ADDRESS:-$CUSTOMER}" | tr '[:upper:]' '[:lower:]')
echo "$ADDRESS" | LC_ALL=C grep -Eq '^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$' || { echo "address invalid: $ADDRESS"; exit 1; }

environments='staging prod'
file=$CUSTOMER.yaml
orders() { echo "kubernetes/customers/orders/$1"; }

case $ACTION in
  create)
    for e in $environments; do
      [ ! -e "$(orders "$e")/$file" ] || { echo "$CUSTOMER already exists in $e"; exit 1; }
      ! grep -rlx "  address: $ADDRESS" "$(orders "$e")" > /dev/null || { echo "address $ADDRESS is taken in $e"; exit 1; }
    done
    ;;
  cancel)
    for e in $environments; do
      [ -e "$(orders "$e")/$file" ] || { echo "$CUSTOMER does not exist in $e"; exit 1; }
    done
    ;;
  *) echo "unknown action: $ACTION"; exit 1 ;;
esac

apply_change() {
  dir=$(orders "$1")
  if [ "$ACTION" = create ]; then
    printf 'apiVersion: customers.tim275.github.io/v1alpha1\nkind: N8nInstance\nmetadata:\n  name: %s\nspec:\n  address: %s\n' "$CUSTOMER" "$ADDRESS" > "$dir/$file"
    F=$file yq -i '.resources = ((.resources // []) + [strenv(F)] | unique | sort)' "$dir/kustomization.yaml"
  else
    rm "$dir/$file"
    F=$file yq -i 'del(.resources[] | select(. == strenv(F)))' "$dir/kustomization.yaml"
  fi
}

start=$(git rev-parse HEAD)
for e in $environments; do
  branch=customer/$ACTION-$CUSTOMER-${GITHUB_RUN_ID:-local}-$e
  git switch -q -c "$branch" "$start"
  apply_change "$e"
  git add "$(orders "$e")"
  git -c user.name="$GIT_NAME" -c user.email="$GIT_EMAIL" commit -qm "$ACTION $CUSTOMER $e"
  git push -q origin "HEAD:refs/heads/$branch"
  if [ "$e" = staging ]; then
    url=$(gh pr create --base main --head "$branch" --title "$ACTION $CUSTOMER ($e)" --body "Merges itself once the checks pass.")
    gh pr merge --auto --squash "$url"
  else
    gh pr create --base main --head "$branch" --title "$ACTION $CUSTOMER ($e)" --body "Merge by hand once staging runs, then sync customers in Argo CD."
  fi
done
