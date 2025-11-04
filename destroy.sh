#!/bin/bash
set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuración
STACK_NAME="redshift-test-stack"
REGION="us-east-2"

echo -e "${YELLOW}=== Script de Destrucción Completa ===${NC}"
echo "Este script eliminará:"
echo "  1. Recursos gestionados por Terraform"
echo "  2. Stack de CloudFormation"
echo "  3. Estado local de Terraform"
echo ""

# Función para confirmar acción
confirm_action() {
    read -p "¿Estás seguro de continuar? (escribir 'yes' para confirmar): " confirmation
    if [ "$confirmation" != "yes" ]; then
        echo -e "${RED}Operación cancelada por el usuario.${NC}"
        exit 0
    fi
}

# Función para verificar si el stack existe
stack_exists() {
    aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].StackStatus' \
        --output text 2>/dev/null || echo "DOES_NOT_EXIST"
}

# Función para esperar eliminación del stack
wait_for_stack_deletion() {
    echo -e "${YELLOW}Esperando a que el stack se elimine completamente...${NC}"
    aws cloudformation wait stack-delete-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION" 2>/dev/null || true
}

confirm_action

# Paso 1: Destruir recursos con Terraform
echo -e "${YELLOW}Paso 1: Destruyendo recursos con Terraform...${NC}"
if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
    echo "Estado de Terraform encontrado. Ejecutando terraform destroy..."
    
    # Mostrar plan de destrucción
    terraform plan -destroy
    
    echo ""
    read -p "¿Proceder con terraform destroy? (yes/no): " tf_confirm
    if [ "$tf_confirm" = "yes" ]; then
        terraform destroy -auto-approve
        echo -e "${GREEN}✓ Recursos de Terraform destruidos${NC}"
    else
        echo -e "${YELLOW}Terraform destroy omitido${NC}"
    fi
else
    echo -e "${YELLOW}No se encontró estado de Terraform o está vacío. Omitiendo terraform destroy.${NC}"
fi

# Paso 2: Eliminar stack de CloudFormation
echo ""
echo -e "${YELLOW}Paso 2: Eliminando stack de CloudFormation...${NC}"

STACK_STATUS=$(stack_exists)

if [ "$STACK_STATUS" != "DOES_NOT_EXIST" ]; then
    echo "Stack encontrado con estado: $STACK_STATUS"
    
    # Si el stack está en un estado de rollback o fallo, puede necesitar forzar eliminación
    if [[ "$STACK_STATUS" == *"ROLLBACK"* ]] || [[ "$STACK_STATUS" == *"FAILED"* ]]; then
        echo -e "${YELLOW}Stack en estado de error. Intentando eliminación...${NC}"
    fi
    
    echo "Eliminando stack de CloudFormation..."
    aws cloudformation delete-stack \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    wait_for_stack_deletion
    
    # Verificar eliminación
    FINAL_STATUS=$(stack_exists)
    if [ "$FINAL_STATUS" = "DOES_NOT_EXIST" ]; then
        echo -e "${GREEN}✓ Stack de CloudFormation eliminado exitosamente${NC}"
    else
        echo -e "${RED}⚠ El stack aún existe con estado: $FINAL_STATUS${NC}"
        echo "Puede que necesites eliminarlo manualmente desde la consola de AWS."
    fi
else
    echo -e "${YELLOW}El stack de CloudFormation no existe. Omitiendo eliminación.${NC}"
fi

# Paso 3: Limpiar archivos locales de Terraform
echo ""
echo -e "${YELLOW}Paso 3: Limpiando archivos locales de Terraform...${NC}"

read -p "¿Eliminar estado local de Terraform y directorio .terraform? (yes/no): " clean_confirm

if [ "$clean_confirm" = "yes" ]; then
    # Backup del estado antes de eliminar
    if [ -f "terraform.tfstate" ]; then
        BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp terraform.tfstate "$BACKUP_DIR/terraform.tfstate.backup"
        cp terraform.tfstate.backup "$BACKUP_DIR/" 2>/dev/null || true
        echo -e "${GREEN}✓ Backup del estado guardado en $BACKUP_DIR${NC}"
    fi
    
    # Eliminar archivos
    rm -rf .terraform terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl
    echo -e "${GREEN}✓ Archivos locales de Terraform eliminados${NC}"
else
    echo -e "${YELLOW}Archivos locales de Terraform conservados${NC}"
fi

# Resumen final
echo ""
echo -e "${GREEN}=== Destrucción Completa ===${NC}"
echo -e "${GREEN}✓ Proceso de limpieza finalizado${NC}"
echo ""
echo "Verifica en la consola de AWS que todos los recursos fueron eliminados:"
echo "  - CloudFormation: https://console.aws.amazon.com/cloudformation"
echo "  - Redshift: https://console.aws.amazon.com/redshift"
echo "  - IAM Roles: https://console.aws.amazon.com/iam"